function newWgts = getNewWgts(originalVols, newVols, currPrices, cashVal)
% calculate weights associated with new volumes

% get associated trading effects
[tradeBalance, tradeCosts] = getTradeEffects(originalVols, newVols, currPrices);

% get new cash value
newCash = updateCash(cashVal, tradeBalance, tradeCosts);

% get new portfolio value
pfVal = sum(currPrices .* newVols) + newCash;

% get weights
newWgts = [newCash, newVols .* currPrices] ./ pfVal;

end
        