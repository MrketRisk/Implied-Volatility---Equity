IV Quadratic Fit with respect to Moneyness of an option (Sticky Delta) in R
This is a simple project to demonstrate how a Quadratic Equation can fit a Implied Vol curve.
We shall use R to achieve this objective. The assumption here is that the concept of Implied Volatility is well understood and sticky delta. More resources can be found in wikipedia
Steps Performed:
1. Three libraries namely dplyr, derivmkts and RND are needed to achieve this objective
2. Any given day's NIFTY derivatives data can be used. Download the same from NSE's website: https://www.nseindia.com/all-reports. The name of the report is Bhavcopy
3. Implied Volatility requires Spot price, Option Price, Rate of Return, Time till Expiry and Dividend.
4. The spot price is derived from NIFTY futures prices as in S = F * exp (- rate * Time till Expiry). This will ensure that dividend is considered.
5. For the purpose of computing Implied volatility, only the liquid OTM contracts are chosen. There are many ways to determine liquidity, for this project we will use median of contracts traded as the minimum to be considered an option to be deemed liquid.
6. Now, Implied Volatility can be computed for the liquid OTM options
7. For Sticky Delta, Strike Price / Spot Price shall be computed.
8. A quadratic fit shall be established between Moneyness and Implied Volatility. This shall provide coefficients using which the Implied Vol of all the Options shall be computed. Note: The coefficients shall be separately computed for each expiry. The same was achieved by a for loop.
 
