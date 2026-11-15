# pragma version 0.4.3
"""
@title BoostHub Staking v32
@author Curve Finance, modified for CurveYield
@license UNLICENSED
@notice Simplified Curve ChildGauge-derived staking contract for CurveYield BoostHub pools.
@dev Keeps the Curve reward-integral model, strips the receipt-token and all Curve veCRV boost logic,
     forwards deposited want to BoostHub and retains the 24-hour reward checkpoints.
     All deposits start at 10% reward weight immediately, ramp to 50% at day 33,
     then to 100% at day 45. Ramp age starts at the deposit's
     existing twenty-four-hour boundary; maturation is never later than 45 days.
     The ramp applies to every registered reward token. Foregone rewards
     are split 65% to active depositor weight and 35% to the fee receiver.
     Admin fees are paid in each reward token; no fee conversion is performed.
     Reward tokens are imported from the configured Hub PID at deployment and
     from harvest returns and on demand. update_reward_tokens() offers a permissionless refresh.
"""

from ethereum.ercs import IERC20

# Matches IBoostHub v6's unchanged complete poolInfo return layout.
struct BoostHubPoolView:
    asset: address
    gauge: address
    active: bool
    totalStaked: uint256
    rewardTokens: DynArray[address, 9]
    depositor: address
    depositorLocked: bool
    checkpointSelector: bytes4
    platformFeeBps: uint16
    platformFeeRecipient: address
    feeConfigSet: bool
    accRewardPerShare: DynArray[uint256, 9]

interface BoostHub:
    def poolInfo(pid: uint256) -> BoostHubPoolView: view
    def claim(pid: uint256, rewardTokens: DynArray[address, 9], receiver: address) -> (DynArray[address, 9], DynArray[uint256, 9]): nonpayable
    def harvest(pid: uint256) -> (DynArray[address, 9], DynArray[uint256, 9]): nonpayable

# ----------------------------- Events -----------------------------

event Deposit:
    provider: indexed(address)
    value: uint256

event Withdraw:
    provider: indexed(address)
    value: uint256
    fee: uint256

event AddReward:
    reward_token: indexed(address)

event DisableReward:
    reward_token: indexed(address)

event ExternalRewardFunded:
    reward_token: indexed(address)
    funder: indexed(address)
    gross_amount: uint256
    distributable_amount: uint256

event Harvest:
    reward_token: indexed(address)
    gross_amount: uint256
    distributable_amount: uint256

event SetFeeReceiver:
    receiver: address

event SetRewardSmoothing:
    smoothing_units: uint256

event CommitOwnership:
    pending_admin: address

event ApplyOwnership:
    admin: address

# ----------------------------- Constants -----------------------------

MAX_BOOSTHUB_REWARDS: constant(uint256) = 8
MAX_REWARDS: constant(uint256) = 9  # Principal plus up to eight distinct gauge reward tokens
FEE_DENOMINATOR: constant(uint256) = 10000
INACTIVE_ADMIN_BPS: constant(uint256) = 3500


REWARD_TIME_UNIT: constant(uint256) = 8640  # 10 units = 1 day
MAX_REWARD_SMOOTHING_UNITS: constant(uint256) = 300  # 30 days
ACTIVATION_STEP_SECONDS: constant(uint256) = 24 * 3600
ACTIVATION_INDEX_SCALE: constant(uint256) = 10**18
RAMP_STEPS: constant(uint256) = 45  # 45 days at daily cadence
RAMP_SCALE: constant(uint256) = 1320  # Exact 10% starting weight and both daily slopes
RAMP_PHASE1_END: constant(uint256) = 33
RAMP_PHASE1_BASE: constant(uint256) = 132
RAMP_PHASE1_SLOPE: constant(uint256) = 16
RAMP_PHASE2_BASE: constant(uint256) = 660
RAMP_PHASE2_SLOPE: constant(uint256) = 55
MAX_RAMP_CHECKPOINT_STEPS: constant(uint256) = 16

# ----------------------------- Core storage -----------------------------

lp_token: public(immutable(address))
boost_hub: public(immutable(address))
pid: public(immutable(uint256))
staked_balance: public(HashMap[address, uint256])
total_staked: public(uint256)
approved_to_deposit: public(HashMap[address, HashMap[address, bool]])

admin: public(address)
future_admin: public(address)

# ----------------------------- Fixed yield ramp -----------------------------

# Deposits in the same twenty-four-hour boundary share one age bucket. Top-ups never age older deposits.
ramp_deposits: HashMap[address, HashMap[uint256, uint256]]
ramp_cursor: HashMap[address, uint256]
ramp_deposit_weight: HashMap[address, uint256]
total_inactive_units: uint256
activation_rate: uint256
activation_increase_at: HashMap[uint256, uint256]
activation_decrease_at: HashMap[uint256, uint256]
last_activation_boundary: public(uint256)

# Each reward token has its own boundary-weighted integral and deposit-age checkpoints.
activation_reward_q: HashMap[address, uint256]
activation_reward_q_for: HashMap[address, HashMap[address, uint256]]
activation_integral_at: HashMap[address, HashMap[uint256, uint256]]
activation_reward_q_at: HashMap[address, HashMap[uint256, uint256]]

# ----------------------------- Reward accounting -----------------------------

reward_tokens: public(address[MAX_REWARDS])
reward_count: public(uint256)
reward_disabled: public(HashMap[address, bool])
# True when this reward is harvested/claimed from BoostHub; false when funded directly.
reward_from_boosthub: public(HashMap[address, bool])

reward_integral: public(HashMap[address, uint256])
reward_integral_for: public(HashMap[address, HashMap[address, uint256]])
reward_rate: public(HashMap[address, uint256])
reward_period_finish: public(HashMap[address, uint256])
reward_last_update: public(HashMap[address, uint256])
reward_remaining: public(HashMap[address, uint256])
claim_data: HashMap[address, HashMap[address, uint256]]

# 65% of foregone rewards waits here while there is no active depositor weight.
active_reward_redistribution_buffer: public(HashMap[address, uint256])
# The 35% admin share is kept separately for each reward token until explicit transfers.
pending_admin_fee: public(HashMap[address, uint256])

# ----------------------------- Configurable economics -----------------------------

fee_receiver: public(address)

reward_smoothing_units: public(uint256)


# ----------------------------- Constructor -----------------------------

@deploy
def __init__(
    _lp_token: address,
    _boost_hub: address,
    _pid: uint256,
    _admin: address,
    _reward_tokens: address[MAX_BOOSTHUB_REWARDS],
    _fee_receiver: address,
    _reward_smoothing_units: uint256,
):
    assert _lp_token != empty(address)
    assert _boost_hub != empty(address)
    assert _admin != empty(address)
    assert _fee_receiver != empty(address)
    assert _reward_smoothing_units <= MAX_REWARD_SMOOTHING_UNITS

    lp_token = _lp_token
    boost_hub = _boost_hub
    pid = _pid
    self.admin = _admin
    self.fee_receiver = _fee_receiver
    self.reward_smoothing_units = _reward_smoothing_units
    self.last_activation_boundary = block.timestamp // ACTIVATION_STEP_SECONDS * ACTIVATION_STEP_SECONDS

    # Read Hub's reward registry once for principal eligibility and initial import.
    initial_pool: BoostHubPoolView = staticcall BoostHub(_boost_hub).poolInfo(_pid)
    # Want is always internal reward-accounting token 0, even when Hub does not reward want.
    self.reward_tokens[0] = _lp_token
    for hub_token: address in initial_pool.rewardTokens:
        if hub_token == _lp_token:
            self.reward_from_boosthub[_lp_token] = True
            break
    log AddReward(_lp_token)
    encountered_empty: bool = False
    count: uint256 = 1
    for i: uint256 in range(MAX_BOOSTHUB_REWARDS):
        token: address = _reward_tokens[i]
        if token == empty(address):
            encountered_empty = True
        else:
            assert not encountered_empty, "reward slots must be packed"
            assert token != self and token != _lp_token
            assert count < MAX_REWARDS, "too many rewards"
            supported: bool = False
            for hub_token: address in initial_pool.rewardTokens:
                if hub_token == token:
                    supported = True
                    break
            assert supported, "not Hub reward"
            for j: uint256 in range(MAX_BOOSTHUB_REWARDS):
                if j < i:
                    assert token != _reward_tokens[j], "duplicate reward"
            self.reward_tokens[count] = token
            self.reward_from_boosthub[token] = True
            count += 1
            log AddReward(token)
    self.reward_count = count
    self._import_boosthub_rewards(initial_pool.rewardTokens)

    # BoostHub.deposit() pulls the underlying principal token.
    assert extcall IERC20(_lp_token).approve(_boost_hub, max_value(uint256), default_return_value=True)

    log SetFeeReceiver(_fee_receiver)
    log SetRewardSmoothing(_reward_smoothing_units)

# ----------------------------- Basic views/helpers -----------------------------

@internal
@view
def _is_boosthub_reward(_hub: address, _pid: uint256, _token: address) -> bool:
    pool: BoostHubPoolView = staticcall BoostHub(_hub).poolInfo(_pid)
    for token: address in pool.rewardTokens:
        if token == _token:
            return True
    return False

@internal
def _import_boosthub_rewards(_tokens: DynArray[address, MAX_REWARDS]) -> uint256:
    # One source of truth for importing Hub rewards, whether read on demand or
    # returned by Hub.harvest(). Retain local stream state for existing rewards.
    added: uint256 = 0
    for token: address in _tokens:
        assert token != empty(address) and token != self
        if self.reward_from_boosthub[token]:
            continue
        if not self._is_reward_token(token):
            count: uint256 = self.reward_count
            assert count < MAX_REWARDS, "too many rewards"
            self.reward_tokens[count] = token
            self.reward_count = count + 1
            added += 1
            log AddReward(token)
        self.reward_from_boosthub[token] = True
    return added

@external
@nonreentrant
def update_reward_tokens() -> uint256:
    """Permissionlessly import the current PID's Hub rewards; return newly added slots."""
    pool: BoostHubPoolView = staticcall BoostHub(boost_hub).poolInfo(pid)
    return self._import_boosthub_rewards(pool.rewardTokens)

@view
@external
def balanceOf(_addr: address) -> uint256:
    """Internal staked principal getter; this contract does not issue an ERC20 receipt token."""
    return self.staked_balance[_addr]

@internal
@view
def _is_reward_token(_token: address) -> bool:
    for i: uint256 in range(MAX_REWARDS):
        if i >= self.reward_count:
            break
        if self.reward_tokens[i] == _token:
            return True
    return False

@internal
@view
def _mul_ratio_down(_a: uint256, _numerator: uint256, _denominator: uint256) -> uint256:
    if _a == 0 or _numerator == 0:
        return 0
    return _a * _numerator // _denominator

@internal
@view
def _mul_scale_down(_a: uint256, _b: uint256) -> uint256:
    whole_b: uint256 = _b // ACTIVATION_INDEX_SCALE
    rem_b: uint256 = _b % ACTIVATION_INDEX_SCALE
    result: uint256 = 0
    if whole_b != 0:
        assert _a <= max_value(uint256) // whole_b
        result = _a * whole_b
    whole_a: uint256 = _a // ACTIVATION_INDEX_SCALE
    rem_a: uint256 = _a % ACTIVATION_INDEX_SCALE
    fractional: uint256 = whole_a * rem_b + rem_a * rem_b // ACTIVATION_INDEX_SCALE
    assert result <= max_value(uint256) - fractional
    return result + fractional


@internal
@view
def _current_user_inactive(_addr: address) -> uint256:
    if self.ramp_deposit_weight[_addr] == 0:
        return 0
    units: uint256 = 0
    cursor: uint256 = self.ramp_cursor[_addr]
    for i: uint256 in range(RAMP_STEPS):
        start: uint256 = cursor + i * ACTIVATION_STEP_SECONDS
        if start > self.last_activation_boundary:
            break
        amount: uint256 = self.ramp_deposits[_addr][start]
        age: uint256 = (self.last_activation_boundary - start) // ACTIVATION_STEP_SECONDS
        active_units: uint256 = 0
        unused_slope: uint256 = 0
        active_units, unused_slope = self._ramp_parameters(age)
        units += amount * (RAMP_SCALE - active_units)
    return min(self.staked_balance[_addr], units // RAMP_SCALE)

@view
@external
def inactive_balance(_addr: address) -> uint256:
    return self._current_user_inactive(_addr)

@view
@external
def active_balance(_addr: address) -> uint256:
    return self.staked_balance[_addr] - self._current_user_inactive(_addr)

@internal
@view
def _total_inactive() -> uint256:
    return min(self.total_staked, self.total_inactive_units // RAMP_SCALE)

# ----------------------------- Fixed ramp accounting -----------------------------


@internal
@view
def _ramp_parameters(_step: uint256) -> (uint256, uint256):
    # Shared cumulative activation and next-day slope.
    if _step < RAMP_PHASE1_END:
        return RAMP_PHASE1_BASE + _step * RAMP_PHASE1_SLOPE, RAMP_PHASE1_SLOPE
    if _step < RAMP_STEPS:
        return RAMP_PHASE2_BASE + (_step - RAMP_PHASE1_END) * RAMP_PHASE2_SLOPE, RAMP_PHASE2_SLOPE
    return RAMP_SCALE, 0

@internal
def _change_ramp_increase(_boundary: uint256, _delta: uint256, _remove: bool):
    if _remove:
        self.activation_increase_at[_boundary] -= _delta
    else:
        self.activation_increase_at[_boundary] += _delta

@internal
def _change_ramp_decrease(_boundary: uint256, _delta: uint256, _remove: bool):
    if _remove:
        self.activation_decrease_at[_boundary] -= _delta
    else:
        self.activation_decrease_at[_boundary] += _delta

@internal
def _change_ramp_position(_addr: address, _start: uint256, _value: uint256, _remove: bool):
    age: uint256 = (self.last_activation_boundary - _start) // ACTIVATION_STEP_SECONDS
    active_units: uint256 = 0
    slope: uint256 = 0
    active_units, slope = self._ramp_parameters(age)
    inactive_units: uint256 = _value * (RAMP_SCALE - active_units)
    rate: uint256 = _value * slope
    boundary: uint256 = 0
    if _remove:
        self.ramp_deposits[_addr][_start] -= _value
        self.ramp_deposit_weight[_addr] -= _value
        self.total_inactive_units -= inactive_units
        self.activation_rate -= rate
    else:
        self.ramp_deposits[_addr][_start] += _value
        self.ramp_deposit_weight[_addr] += _value
        self.total_inactive_units += inactive_units
        self.activation_rate += rate
    if age < RAMP_PHASE1_END:
        boundary = _start + RAMP_PHASE1_END * ACTIVATION_STEP_SECONDS
        self._change_ramp_increase(boundary, _value * (RAMP_PHASE2_SLOPE - RAMP_PHASE1_SLOPE), _remove)
    if age < RAMP_STEPS:
        boundary = _start + RAMP_STEPS * ACTIVATION_STEP_SECONDS
        self._change_ramp_decrease(boundary, _value * RAMP_PHASE2_SLOPE, _remove)

@internal
def _apply_activation_step(_increase: uint256, _decrease: uint256):
    boundary: uint256 = self.last_activation_boundary + ACTIVATION_STEP_SECONDS
    self.total_inactive_units -= self.activation_rate
    self.activation_rate = self.activation_rate + _increase - _decrease
    self.activation_increase_at[boundary] = 0
    self.activation_decrease_at[boundary] = 0

# Reward checkpointing walks depositor maturity buckets once for all tokens.
# Individual reward integrals remain token-specific because emission histories differ.
# The reward_integral stores accumulated units per 1e18 staking weight; activation_reward_q
# stores the same increments multiplied by their day-boundary index. Their difference
# reconstructs the time-weighted amount across each linear maturity phase.
# Do not round the phase slope before applying the weighted increment: the constants
# below deliberately represent exact fractions in RAMP_SCALE = 1320 units.

# ----------------------------- Reward integral accounting -----------------------------

@internal
def _flush_active_reward_buffer(_token: address):
    buffered: uint256 = self.active_reward_redistribution_buffer[_token]
    if buffered == 0:
        return
    supply: uint256 = self.total_staked
    if supply == 0:
        return
    inactive: uint256 = self._total_inactive()
    active_supply: uint256 = supply - inactive
    if active_supply == 0:
        return
    self.active_reward_redistribution_buffer[_token] = 0
    integral_add: uint256 = buffered * 10**18 // active_supply
    self.reward_integral[_token] += integral_add
    self.activation_reward_q[_token] += integral_add * (self.last_activation_boundary // ACTIVATION_STEP_SECONDS)

@internal
def _update_reward_integral_to(_token: address, _timestamp: uint256):
    finish: uint256 = self.reward_period_finish[_token]
    applicable: uint256 = min(_timestamp, finish)
    last: uint256 = self.reward_last_update[_token]
    if applicable <= last:
        return

    elapsed: uint256 = applicable - last
    if self.total_staked != 0:
        emission: uint256 = elapsed * self.reward_rate[_token]
        if applicable == finish:
            emission = self.reward_remaining[_token]
        elif emission > self.reward_remaining[_token]:
            emission = self.reward_remaining[_token]
        if emission != 0:
            self.reward_remaining[_token] -= emission
            self._distribute_immediate(_token, emission)
    self.reward_last_update[_token] = applicable

@internal
def _advance_reward_integrals(_max_steps: uint256):
    current_boundary: uint256 = block.timestamp // ACTIVATION_STEP_SECONDS * ACTIVATION_STEP_SECONDS
    # For the usual same-day checkpoint (or no maturing deposits), building an
    # active-token list costs more than a single short registry pass. Preserve
    # the original single-pass behavior in that case.
    if self.last_activation_boundary == current_boundary or self.total_inactive_units == 0:
        self.last_activation_boundary = current_boundary
        for i: uint256 in range(MAX_REWARDS):
            if i >= self.reward_count:
                break
            token: address = self.reward_tokens[i]
            self._update_reward_integral_to(token, block.timestamp)
            self._flush_active_reward_buffer(token)
        return

    # Active here means the token has unfinished emissions or an undistributed
    # active-share buffer. Historical user claims remain registered separately.
    # A dormant token is reselected automatically when _schedule_reward starts
    # another stream; no owner-maintained active state or secondary ledger.
    pending_indices: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    pending_count: uint256 = 0
    for i: uint256 in range(MAX_REWARDS):
        if i >= self.reward_count:
            break
        token: address = self.reward_tokens[i]
        has_emission: bool = (
            self.reward_remaining[token] != 0
            and self.reward_period_finish[token] > self.reward_last_update[token]
        )
        if has_emission or self.active_reward_redistribution_buffer[token] != 0:
            pending_indices[pending_count] = i
            pending_count += 1

    for j: uint256 in range(RAMP_STEPS):
        if j >= _max_steps or self.last_activation_boundary >= current_boundary or self.total_inactive_units == 0:
            break
        boundary: uint256 = self.last_activation_boundary + ACTIVATION_STEP_SECONDS
        increase: uint256 = self.activation_increase_at[boundary]
        decrease: uint256 = self.activation_decrease_at[boundary]
        needs_snapshot: bool = increase != 0 or decrease != 0
        for k: uint256 in range(MAX_REWARDS):
            if k >= pending_count:
                break
            self._update_reward_integral_to(self.reward_tokens[pending_indices[k]], boundary)
        if needs_snapshot:
            # Old users read these two historical values directly. Preserve
            # nonzero plateau snapshots even after emissions finish. Zero-valued
            # snapshots need no SSTORE: an unset mapping entry already reads zero.
            for i: uint256 in range(MAX_REWARDS):
                if i >= self.reward_count:
                    break
                token: address = self.reward_tokens[i]
                integral: uint256 = self.reward_integral[token]
                moment: uint256 = self.activation_reward_q[token]
                if integral != 0:
                    self.activation_integral_at[token][boundary] = integral
                if moment != 0:
                    self.activation_reward_q_at[token][boundary] = moment
        self._apply_activation_step(increase, decrease)
        self.last_activation_boundary = boundary
        for k: uint256 in range(MAX_REWARDS):
            if k >= pending_count:
                break
            self._flush_active_reward_buffer(self.reward_tokens[pending_indices[k]])
    if self.total_inactive_units == 0:
        self.last_activation_boundary = current_boundary
    # A partial advance must not allocate later rewards using an earlier ramp weight.
    if self.last_activation_boundary == current_boundary:
        for k: uint256 in range(MAX_REWARDS):
            if k >= pending_count:
                break
            token: address = self.reward_tokens[pending_indices[k]]
            self._update_reward_integral_to(token, block.timestamp)
            self._flush_active_reward_buffer(token)

@internal
def _update_all_reward_integrals():
    self._advance_reward_integrals(RAMP_STEPS)
    assert self.last_activation_boundary == block.timestamp // ACTIVATION_STEP_SECONDS * ACTIVATION_STEP_SECONDS, "ramp checkpoint overflow"

@external
@nonreentrant
def checkpoint_ramp(_steps: uint256 = MAX_RAMP_CHECKPOINT_STEPS) -> bool:
    """Advance at most 16 ramp boundaries; repeat until True before a large-backlog user action."""
    assert _steps != 0 and _steps <= MAX_RAMP_CHECKPOINT_STEPS, "invalid checkpoint steps"
    self._advance_reward_integrals(_steps)
    return self.last_activation_boundary == block.timestamp // ACTIVATION_STEP_SECONDS * ACTIVATION_STEP_SECONDS

@internal
def _checkpoint_user_current(_addr: address, _claim: bool, _claim_token: address) -> DynArray[address, MAX_REWARDS]:
    # Cache each reward's integral baseline, then traverse maturity buckets once.
    # On each bucket/phase, update each token's accrual without re-reading the
    # depositor's buckets and phase metadata for every reward token.
    bal: uint256 = self.staked_balance[_addr]
    n: uint256 = self.reward_count
    tokens: DynArray[address, MAX_REWARDS] = []
    prior_integrals: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    current_integrals: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    prior_qs: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    current_qs: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    penalties: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    accrued_indices: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
    accrued_count: uint256 = 0

    for r: uint256 in range(MAX_REWARDS):
        if r >= n:
            break
        token: address = self.reward_tokens[r]
        tokens.append(token)
        prior_integrals[r] = self.reward_integral_for[token][_addr]
        current_integrals[r] = self.reward_integral[token]
        if current_integrals[r] > prior_integrals[r]:
            # Dormant tokens need neither weighted-integral storage read.
            prior_qs[r] = self.activation_reward_q_for[token][_addr]
            current_qs[r] = self.activation_reward_q[token]
            accrued_indices[accrued_count] = r
            accrued_count += 1

    if self.ramp_deposit_weight[_addr] != 0:
        cursor: uint256 = self.ramp_cursor[_addr]
        last_boundary: uint256 = self.last_activation_boundary
        next_cursor: uint256 = last_boundary
        matured_weight: uint256 = 0

        # One bucket traversal, one set of two ramp phases; all reward
        # tokens share the deposit amount, maturity and phase information.
        for bucket: uint256 in range(RAMP_STEPS):
            start: uint256 = cursor + bucket * ACTIVATION_STEP_SECONDS
            if start > last_boundary:
                break
            amount: uint256 = self.ramp_deposits[_addr][start]
            if amount == 0:
                continue
            finish: uint256 = start + RAMP_STEPS * ACTIVATION_STEP_SECONDS

            if accrued_count != 0:
                start_boundary_index: uint256 = start // ACTIVATION_STEP_SECONDS
                # Penalties remove the immature share of newly accrued integrals.
                # Effective fractions start at 10%, reach 50% at day 33, then
                # 100% at day 45; both slopes share a 1320 denominator.
                effective: uint256[MAX_REWARDS] = empty(uint256[MAX_REWARDS])
                for phase: uint256 in range(2):
                    first: uint256 = 0
                    last: uint256 = RAMP_PHASE1_END
                    base: uint256 = RAMP_PHASE1_BASE
                    slope: uint256 = RAMP_PHASE1_SLOPE
                    if phase == 1:
                        first = RAMP_PHASE1_END
                        last = RAMP_STEPS
                        base = RAMP_PHASE2_BASE
                        slope = RAMP_PHASE2_SLOPE

                    begin: uint256 = start + first * ACTIVATION_STEP_SECONDS
                    if begin > last_boundary:
                        break
                    end: uint256 = start + last * ACTIVATION_STEP_SECONDS
                    boundary_index: uint256 = start_boundary_index + first

                    for k: uint256 in range(MAX_REWARDS):
                        if k >= accrued_count:
                            break
                        r: uint256 = accrued_indices[k]
                        token: address = tokens[r]
                        from_integral: uint256 = prior_integrals[r]
                        from_q: uint256 = prior_qs[r]
                        boundary_integral: uint256 = self.activation_integral_at[token][begin]
                        if boundary_integral > from_integral:
                            from_integral = boundary_integral
                            from_q = self.activation_reward_q_at[token][begin]
                        to_integral: uint256 = current_integrals[r]
                        to_q: uint256 = current_qs[r]
                        if end <= last_boundary:
                            to_integral = self.activation_integral_at[token][end]
                            to_q = self.activation_reward_q_at[token][end]
                        if to_integral > from_integral:
                            delta: uint256 = to_integral - from_integral
                            moment: uint256 = to_q - from_q - boundary_index * delta
                            effective[r] += (base * delta + slope * moment) // RAMP_SCALE

                for k: uint256 in range(MAX_REWARDS):
                    if k >= accrued_count:
                        break
                    r: uint256 = accrued_indices[k]
                    delta: uint256 = current_integrals[r] - prior_integrals[r]
                    effective_integral: uint256 = effective[r]
                    if finish <= last_boundary:
                        finished_at: uint256 = self.activation_integral_at[tokens[r]][finish]
                        effective_integral += current_integrals[r] - max(prior_integrals[r], finished_at)
                    inactive_integral: uint256 = delta - min(delta, effective_integral)
                    if inactive_integral != 0:
                        penalties[r] += self._mul_scale_down(amount, inactive_integral) + 1

            # Prune matured deposits in this same scan; no second bucket pass.
            if finish <= last_boundary:
                self.ramp_deposits[_addr][start] = 0
                matured_weight += amount
            else:
                next_cursor = min(next_cursor, start)
        if matured_weight != 0:
            self.ramp_deposit_weight[_addr] -= matured_weight
        self.ramp_cursor[_addr] = next_cursor

    for r: uint256 in range(MAX_REWARDS):
        if r >= n:
            break
        token: address = tokens[r]
        integral: uint256 = current_integrals[r]
        prior: uint256 = prior_integrals[r]
        earned: uint256 = 0
        if integral > prior:
            earned = self._mul_scale_down(bal, integral - prior)
            earned -= min(earned, penalties[r])
        if integral != prior:
            self.reward_integral_for[token][_addr] = integral
        if current_qs[r] != prior_qs[r]:
            self.activation_reward_q_for[token][_addr] = current_qs[r]
        if _claim and (_claim_token == empty(address) or _claim_token == token):
            claimed: uint256 = self.claim_data[_addr][token]
            if claimed != 0:
                self.claim_data[_addr][token] = 0
            claimed += earned
            if claimed != 0:
                assert extcall IERC20(token).transfer(_addr, claimed, default_return_value=True)
        elif earned != 0:
            self.claim_data[_addr][token] += earned
    return tokens

@external
@nonreentrant
def checkpoint(_addr: address):
    """Checkpoint smoothed reward accrual and the fixed yield ramp without harvesting BoostHub."""
    self._update_all_reward_integrals()
    self._checkpoint_user_current(_addr, False, empty(address))

@view
@external
def claimable_reward(_addr: address, _token: address) -> uint256:
    # Conservative stored amount. State-changing claim/checkpoint realizes current streamed accrual.
    assert self._is_reward_token(_token), "unknown reward"
    return self.claim_data[_addr][_token]

# ----------------------------- BoostHub writes -----------------------------

@internal
def _forward_deposit_to_boosthub(_value: uint256, _caller: address):
    assert extcall IERC20(lp_token).transferFrom(_caller, self, _value, default_return_value=True)
    raw_call(
        boost_hub,
        concat(method_id("deposit(uint256,uint256)"), convert(pid, bytes32), convert(_value, bytes32)),
    )


@internal
def _withdraw_from_boosthub(_value: uint256):
    raw_call(
        boost_hub,
        concat(method_id("withdraw(uint256,uint256)"), convert(pid, bytes32), convert(_value, bytes32)),
    )


@internal
def _process_pending_transfers():
    for i: uint256 in range(MAX_REWARDS):
        if i >= self.reward_count:
            break
        token: address = self.reward_tokens[i]
        amount: uint256 = self.pending_admin_fee[token]
        if amount != 0:
            self.pending_admin_fee[token] = 0
            assert extcall IERC20(token).transfer(self.fee_receiver, amount, default_return_value=True)

@internal
def _distribute_immediate(_token: address, _amount: uint256):
    if _amount == 0:
        return
    supply: uint256 = self.total_staked
    if supply == 0:
        self.reward_remaining[_token] += _amount
        return
    inactive: uint256 = self._total_inactive()
    active_supply: uint256 = supply - inactive
    inactive_nominal: uint256 = 0
    if inactive != 0:
        inactive_nominal = self._mul_ratio_down(_amount, inactive, supply)
    admin_share: uint256 = inactive_nominal * INACTIVE_ADMIN_BPS // FEE_DENOMINATOR
    self.pending_admin_fee[_token] += admin_share
    # The active portion plus the 65% foregone share stays with active depositors.
    active_amount: uint256 = _amount - admin_share
    if active_supply != 0:
        integral_add: uint256 = active_amount * 10**18 // active_supply
        self.reward_integral[_token] += integral_add
        self.activation_reward_q[_token] += integral_add * (self.last_activation_boundary // ACTIVATION_STEP_SECONDS)
    else:
        self.active_reward_redistribution_buffer[_token] += active_amount

@internal
def _schedule_reward(_token: address, _amount: uint256):
    if _amount == 0:
        return
    # The prior stream has been checkpointed, so reward_remaining is its undistributed carry.
    previous_remaining: uint256 = self.reward_remaining[_token]
    total_amount: uint256 = _amount + previous_remaining
    duration: uint256 = self.reward_smoothing_units * REWARD_TIME_UNIT
    if duration == 0:
        self.reward_remaining[_token] = 0
        self.reward_rate[_token] = 0
        self.reward_last_update[_token] = block.timestamp
        self.reward_period_finish[_token] = block.timestamp
        self._distribute_immediate(_token, total_amount)
    else:
        next_duration: uint256 = duration
        if previous_remaining != 0 and block.timestamp < self.reward_period_finish[_token]:
            if _amount <= previous_remaining:
                # Extend the current remaining period in proportion to the added rewards.
                # Cap at one configured smoothing duration. Larger top-ups restart in full.
                remaining_time: uint256 = self.reward_period_finish[_token] - block.timestamp
                extension: uint256 = duration * _amount // previous_remaining
                next_duration = min(duration, remaining_time + extension)

        self.reward_remaining[_token] = total_amount
        self.reward_rate[_token] = total_amount // next_duration
        self.reward_last_update[_token] = block.timestamp
        self.reward_period_finish[_token] = block.timestamp + next_duration

@internal
def _harvest():
    # Harvest is explicit. Deposits and withdrawals never call it.
    self._update_all_reward_integrals()
    if self.total_staked == 0:
        self._process_pending_transfers()
        return

    # Reuse Hub's harvested reward registry instead of a second poolInfo() read.
    hub_tokens: DynArray[address, MAX_REWARDS] = []
    hub_amounts: DynArray[uint256, MAX_REWARDS] = []
    hub_tokens, hub_amounts = extcall BoostHub(boost_hub).harvest(pid)
    self._import_boosthub_rewards(hub_tokens)

    selected: DynArray[address, MAX_REWARDS] = []
    for token: address in hub_tokens:
        # Import just established Hub provenance for this list.
        if not self.reward_disabled[token]:
            selected.append(token)

    if len(selected) != 0:
        # Hub returns the actual transferred amounts in the same order as selected.
        # Reward tokens are standard ERC-20s (no transfer fees or rebasing).
        claimed_tokens: DynArray[address, MAX_REWARDS] = []
        claimed_amounts: DynArray[uint256, MAX_REWARDS] = []
        claimed_tokens, claimed_amounts = extcall BoostHub(boost_hub).claim(pid, selected, self)
        for i: uint256 in range(MAX_REWARDS):
            if i >= len(claimed_amounts):
                break
            gross: uint256 = claimed_amounts[i]
            if gross != 0:
                self._schedule_reward(selected[i], gross)
                log Harvest(selected[i], gross, gross)

    # Pay accrued 35% ramp admin shares in their original reward tokens.
    self._process_pending_transfers()

@external
@nonreentrant
def harvest():
    self._harvest()

@external
@nonreentrant
def harvest_and_claim() -> DynArray[address, MAX_REWARDS]:
    self._harvest()
    return self._checkpoint_user_current(msg.sender, True, empty(address))

# ----------------------------- Deposit accounting -----------------------------


@internal
def _check_deposit_authorization(_addr: address, _caller: address):
    assert _addr != empty(address)
    if _addr != _caller:
        assert self.approved_to_deposit[_caller][_addr], "Not approved"

@internal
def _add_method1_deposit(_addr: address, _value: uint256):
    if self.ramp_deposit_weight[_addr] == 0:
        self.ramp_cursor[_addr] = self.last_activation_boundary
    self._change_ramp_position(_addr, self.last_activation_boundary, _value, False)

@external
@nonreentrant
def deposit(_value: uint256, _addr: address = msg.sender):
    """Deposit want using the fixed 45-day, daily-bucket yield ramp."""
    self._check_deposit_authorization(_addr, msg.sender)
    if _value != 0:
        self._update_all_reward_integrals()
        self._checkpoint_user_current(_addr, False, empty(address))
        self.total_staked += _value
        self.staked_balance[_addr] += _value
        self._add_method1_deposit(_addr, _value)
        self._forward_deposit_to_boosthub(_value, msg.sender)
    log Deposit(_addr, _value)


# ----------------------------- Withdrawals -----------------------------


@internal
def _remove_method1_principal(_addr: address, _value: uint256):
    if self.ramp_deposit_weight[_addr] == 0:
        return
    inactive: uint256 = self._current_user_inactive(_addr)
    active: uint256 = self.staked_balance[_addr] - inactive
    if _value < self.staked_balance[_addr] and _value <= active:
        return
    target: uint256 = 0
    if _value < self.staked_balance[_addr]:
        target = inactive - (_value - active)
    cursor: uint256 = self.ramp_cursor[_addr]
    for i: uint256 in range(RAMP_STEPS):
        start: uint256 = cursor + i * ACTIVATION_STEP_SECONDS
        if start > self.last_activation_boundary:
            break
        amount: uint256 = self.ramp_deposits[_addr][start]
        if amount != 0:
            remaining: uint256 = 0
            if target != 0:
                remaining = amount * target // inactive
            self._change_ramp_position(_addr, start, amount - remaining, True)

@external
@nonreentrant
def withdraw(_value: uint256):
    """Withdraw principal without a withdrawal fee or timelock."""
    assert _value <= self.staked_balance[msg.sender]
    self._update_all_reward_integrals()
    self._checkpoint_user_current(msg.sender, False, empty(address))
    self._remove_method1_principal(msg.sender, _value)
    self.staked_balance[msg.sender] -= _value
    self.total_staked -= _value
    self._withdraw_from_boosthub(_value)
    assert extcall IERC20(lp_token).transfer(msg.sender, _value, default_return_value=True)
    log Withdraw(msg.sender, _value, 0)


# ----------------------------- Claims -----------------------------

@external
@nonreentrant
def claim_rewards():
    self._update_all_reward_integrals()
    self._checkpoint_user_current(msg.sender, True, empty(address))

@external
@nonreentrant
def claim_reward(_token: address):
    assert self._is_reward_token(_token), "unknown reward"
    self._update_all_reward_integrals()
    self._checkpoint_user_current(msg.sender, True, _token)

@external
def set_approve_deposit(addr: address, can_deposit: bool):
    self.approved_to_deposit[addr][msg.sender] = can_deposit

# ----------------------------- Reward-token administration -----------------------------

@external
def add_reward(_reward_token: address):
    """Register an admin-approved reward already supported by BoostHub for this PID."""
    assert msg.sender == self.admin, "admin only"
    assert _reward_token != empty(address) and _reward_token != self
    assert not self._is_reward_token(_reward_token), "duplicate reward"
    assert self.reward_count < MAX_REWARDS
    assert self._is_boosthub_reward(boost_hub, pid, _reward_token)
    self.reward_tokens[self.reward_count] = _reward_token
    self.reward_from_boosthub[_reward_token] = True
    self.reward_count += 1
    log AddReward(_reward_token)

@external
def add_external_reward(_reward_token: address):
    """Register a generic directly funded reward; refresh promotes it if the Hub adds it."""
    assert msg.sender == self.admin, "admin only"
    assert _reward_token != empty(address) and _reward_token != self
    assert not self._is_reward_token(_reward_token), "duplicate reward"
    assert self.reward_count < MAX_REWARDS
    idx: uint256 = self.reward_count
    self.reward_tokens[idx] = _reward_token
    self.reward_from_boosthub[_reward_token] = False
    self.reward_count = idx + 1
    log AddReward(_reward_token)

@external
@nonreentrant
def deposit_reward_token(_reward_token: address, _amount: uint256):
    """Fund a registered external reward stream. Does not call BoostHub."""
    assert _amount != 0, "zero amount"
    assert self._is_reward_token(_reward_token), "unknown reward"
    assert not self.reward_disabled[_reward_token], "reward disabled"
    assert not self.reward_from_boosthub[_reward_token], "BoostHub reward"

    self._update_all_reward_integrals()
    before: uint256 = staticcall IERC20(_reward_token).balanceOf(self)
    assert extcall IERC20(_reward_token).transferFrom(msg.sender, self, _amount, default_return_value=True)
    gross: uint256 = staticcall IERC20(_reward_token).balanceOf(self) - before
    assert gross != 0, "zero received"

    self._schedule_reward(_reward_token, gross)

    self._process_pending_transfers()
    log ExternalRewardFunded(_reward_token, msg.sender, gross, gross)

@external
@nonreentrant
def disable_reward(_reward_token: address):
    assert msg.sender == self.admin, "admin only"
    assert self._is_reward_token(_reward_token)
    assert _reward_token != lp_token, "want required"
    self._update_all_reward_integrals()
    assert block.timestamp >= self.reward_period_finish[_reward_token], "reward stream active"
    if self.reward_from_boosthub[_reward_token]:
        before: uint256 = staticcall IERC20(_reward_token).balanceOf(self)
        raw_call(boost_hub, concat(method_id("harvest(uint256)"), convert(pid, bytes32)))
        selected: DynArray[address, MAX_REWARDS] = [_reward_token]
        extcall BoostHub(boost_hub).claim(pid, selected, self)
        assert staticcall IERC20(_reward_token).balanceOf(self) == before, "fresh reward received"
    self.reward_disabled[_reward_token] = True
    log DisableReward(_reward_token)

# ----------------------------- Config administration -----------------------------


@external
def set_fee_receiver(_receiver: address):
    assert msg.sender == self.admin and _receiver != empty(address)
    self.fee_receiver = _receiver
    log SetFeeReceiver(_receiver)

@external
def set_reward_smoothing_units(_units: uint256):
    assert msg.sender == self.admin and _units <= MAX_REWARD_SMOOTHING_UNITS
    self.reward_smoothing_units = _units
    log SetRewardSmoothing(_units)


# ----------------------------- Admin role transfer -----------------------------

@external
def commit_transfer_ownership(_new_admin: address):
    assert msg.sender == self.admin and _new_admin != empty(address)
    self.future_admin = _new_admin
    log CommitOwnership(_new_admin)

@external
def accept_transfer_ownership():
    assert msg.sender == self.future_admin and msg.sender != empty(address)
    self.admin = msg.sender
    self.future_admin = empty(address)
    log ApplyOwnership(msg.sender)
