# Generic LINKAGE functional forms.
#
# These helpers encode Annex C (pp. 70--72) and Annex D (pp. 73--75) of the
# LINKAGE Technical Reference Document.  The JuMP equation blocks keep the
# paper-numbered constraints explicit, while these functions are used for
# calibration, validation, and any production/trade nests that need the same
# CES/CET algebra outside a JuMP macro.

const _LINKAGE_EPS = 1.0e-12

"""
    ces_demand(alpha, lambda, P, Pi, V, sigma)

Annex C CES input demand, eq. (1):
`Xi = alpha_i * lambda_i^(sigma - 1) * (P / Pi)^sigma * V`.

For `sigma == 0`, this reduces to the Leontief case `Xi = alpha_i * V / lambda_i`.
"""
function ces_demand(alpha::Real, lambda::Real, P::Real, Pi::Real, V::Real, sigma::Real)
    if isapprox(float(sigma), 0.0; atol=_LINKAGE_EPS)
        return alpha * V / lambda
    end
    return alpha * lambda^(sigma - 1) * (P / Pi)^sigma * V
end

"""
    ces_price(alpha, prices, lambdas, sigma)

Annex C CES dual price, eq. (2):
`P = [sum_i alpha_i * (Pi / lambda_i)^(1 - sigma)]^(1 / (1 - sigma))`.

Special cases:
- `sigma == 0`: Leontief weighted price, Annex C eq. (2').
- `sigma == 1`: Cobb-Douglas dual price, Annex C eq. (2''), with unit scale `A = 1`.
"""
function ces_price(alpha, prices, lambdas, sigma::Real)
    @assert length(alpha) == length(prices) == length(lambdas) "CES vectors must have the same length"
    if isapprox(float(sigma), 0.0; atol=_LINKAGE_EPS)
        return sum(alpha[n] * prices[n] / lambdas[n] for n in eachindex(alpha))
    elseif isapprox(float(sigma), 1.0; atol=_LINKAGE_EPS)
        return prod((prices[n] / (alpha[n] * lambdas[n]))^alpha[n] for n in eachindex(alpha))
    else
        return sum(alpha[n] * (prices[n] / lambdas[n])^(1 - sigma) for n in eachindex(alpha))^(1 / (1 - sigma))
    end
end

"""
    ces_alpha(Pi, P, Xi, V, sigma; lambda=1.0)

Annex C calibration inversion for a CES share parameter:
`alpha_i = (Pi / P)^sigma * Xi / V` when technology shifters are one.
With a non-unit shifter, this inverts Annex C eq. (1):
`alpha_i = Xi / (lambda_i^(sigma - 1) * (P / Pi)^sigma * V)`.
"""
function ces_alpha(Pi::Real, P::Real, Xi::Real, V::Real, sigma::Real; lambda::Real=1.0)
    if isapprox(float(sigma), 0.0; atol=_LINKAGE_EPS)
        return Xi * lambda / V
    end
    return Xi / (lambda^(sigma - 1) * (P / Pi)^sigma * V)
end

"""
    cet_supply(gamma, Pi, P, V, omega)

Annex C CET supply/allocation first-order condition:
`Xi = gamma_i * (Pi / P)^omega * V`.
"""
function cet_supply(gamma::Real, Pi::Real, P::Real, V::Real, omega::Real)
    return gamma * (Pi / P)^omega * V
end

"""
    cet_price(gamma, prices, omega)

Annex C CET dual price:
`P = [sum_i gamma_i * Pi^(1 + omega)]^(1 / (1 + omega))`.
"""
function cet_price(gamma, prices, omega::Real)
    @assert length(gamma) == length(prices) "CET vectors must have the same length"
    return sum(gamma[n] * prices[n]^(1 + omega) for n in eachindex(gamma))^(1 / (1 + omega))
end

"""
    cet_gamma_from_primal(g, omega)
    cet_primal_from_gamma(gamma, omega)

Annex C mapping between CET primal shares and dual/FOC shares:
`gamma_i = g_i^(-omega)` and `g_i = (1 / gamma_i)^(1 / omega)`.
"""
cet_gamma_from_primal(g::Real, omega::Real) = g^(-omega)
cet_primal_from_gamma(gamma::Real, omega::Real) = (1 / gamma)^(1 / omega)

"""
    armington_market_shares(values)

Annex D eq. (D-3): market/value shares `mu_i = value_i / sum(value)`.
Pass tariff-inclusive import values such as `PM[rp,r] * WTF[rp,r]`.
"""
function armington_market_shares(values)
    total = sum(values)
    @assert total > 0 "market-share denominator must be positive"
    return [x / total for x in values]
end

"""
    armington_beta(mu, PM, sigma_w, theta_w)

Annex D eq. (D-8), normalized beta parameters for long-run Armington shares:
`beta_i = mu_i * PM_i^((sigma_w - 1) / theta_w) / sum_j mu_j * PM_j^((sigma_w - 1) / theta_w)`.
"""
function armington_beta(mu, PM, sigma_w::Real, theta_w::Real)
    @assert 0 < theta_w <= 1 "theta_w must be in (0, 1]"
    @assert length(mu) == length(PM) "Armington beta vectors must have the same length"
    expo = (sigma_w - 1) / theta_w
    raw = [mu[n] * PM[n]^expo for n in eachindex(mu)]
    denom = sum(raw)
    @assert denom > 0 "Armington beta denominator must be positive"
    return raw ./ denom
end

"""
    armington_alpha_update(mu_lag, beta, theta_w)

Annex D eq. (D-4): update CES Armington share parameters:
`alpha_i,t = mu_i,t-1^(1-theta_w) * beta_i^theta_w / sum_j ...`.
"""
function armington_alpha_update(mu_lag, beta, theta_w::Real)
    @assert 0 < theta_w <= 1 "theta_w must be in (0, 1]"
    @assert length(mu_lag) == length(beta) "Armington alpha vectors must have the same length"
    raw = [mu_lag[n]^(1 - theta_w) * beta[n]^theta_w for n in eachindex(mu_lag)]
    denom = sum(raw)
    @assert denom > 0 "Armington alpha denominator must be positive"
    return raw ./ denom
end

"""
    armington_long_run_elasticity(sigma_w, theta_w)

Annex D implication after eq. (D-7): long-run elasticity is
`(sigma_w - 1) / theta_w + 1`, which exceeds the short-run elasticity
when `theta_w < 1`.
"""
function armington_long_run_elasticity(sigma_w::Real, theta_w::Real)
    @assert 0 < theta_w <= 1 "theta_w must be in (0, 1]"
    return (sigma_w - 1) / theta_w + 1
end
