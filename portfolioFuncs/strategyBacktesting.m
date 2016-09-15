% specify ticker symbols

tickSymbs = {'^STOXX50E', ... % STOXX Europe 50
    '^GDAXI', ... % DAX
    '^GSPC'};     % S&P 500
    
etfSymbs = {'EEM', ... % iShares MSCI Emerging Markets; USD
    'BTUSX', ... % Deutsche US Bond Index Institutional (BTUSX); USD
    'SPY', ... % SPDR S&P 500; USD
    'EWJ', ... % iShares MSCI Japan; USD
    'SGOL', ... % ETFS Physical Swiss Gold; USD
    'EFA', ... % iShares MSCI EAFE; USD
    'EWZ', ... % iShares MSCI Brazil Capped; USD
    'HYG', ... % iShares iBoxx $ High Yield Corporate Bd; USD
    'XOP', ... % SPDR S&P Oil & Gas Explor & Prodtn ETF; USD
    };
    
% specify beginning and ending as string variables
dateBeg = '01011990';   %  day, month, year: ddmmyyyy
dateEnd = '01092016';


%% download prices

%prices = getPrices(dateBeg, dateEnd, etfSymbs);
%writetable(prices, '~/someETFprices.csv')

%% 

prices = readtable('~/someETFprices.csv');

%%

plot(prices.Date, prices{:, 2:end})
datetick 'x'
grid on
grid minor

%% visualize missing values

imagesc(isnan(prices{:, 2:end}), [0 1])
set(gca, 'XTickLabel', tabnames(prices(:, 2:end)))
yTicks = get(gca, 'YTick');
set(gca, 'YTickLabel', datestr(prices.Date(yTicks)))

%% get sub-sample without NaNs

subPrices = cleanSubsample(prices, 6);
assert(~any(any(isnan(subPrices{:, :}))), 'There are still missing values')

%%

plot(subPrices.Date, subPrices{:, 2:end})
datetick 'x'
grid on
grid minor

%% visualize normed prices

% get normed prices
nObs = size(subPrices, 1);
normedPrices = subPrices;
xxnormedPrices = subPrices{:, 2:end} ./ repmat(subPrices{1, 2:end}, nObs, 1);
normedPrices{:, 2:end} = xxnormedPrices;

% make plot
plot(normedPrices.Date, normedPrices{:, 2:end})
datetick 'x'
grid on
grid minor
legend(tabnames(normedPrices(:, 2:end)))

%% get subset of data without missing observations

% get asset names
etfNames = tabnames(normedPrices(:, 2:end));

% attach cash and sort
univPrices = subPrices;
univPrices.Cash = ones(nObs, 1);
univPrices = univPrices(:, ['Date', 'Cash', etfNames]);

%% try to get equal weights portfolio

% get portfolio value
initValue = 10000;

% get target weights
nEtfs = size(subPrices, 2) - 1;
targetWgts = [0, 1./nEtfs*ones(1, nEtfs)];

% current prices
currPrices = subPrices{1, 2:end};

% current vols
currVols = [initValue, 1./nEtfs*zeros(1, nEtfs)];

%%

nDays = size(subPrices, 1);

% preallocation
stratVols = zeros(nDays, nEtfs + 1);
realWgts = zeros(nDays, nEtfs + 1);
cashDrains = zeros(nDays, 1);

currETFVols = zeros(1, nEtfs);
cashVal = initValue;

for ii=1:nDays
    % get associated weights
    [bestVols, newCash, newWgts, cashDrain] = ...
        realizeWgts(targetWgts, currETFVols, subPrices{ii, 2:end}, cashVal);
    
    % store best volumes
    stratVols(ii, 1) = newCash;
    stratVols(ii, 2:end) = bestVols;
    
    % store cash drains
    cashDrains(ii) = cashDrain;
    
    % store weights
    realWgts(ii, :) = newWgts;

    % overwrite old variables
    cashVal = newCash;
    currETFVols = bestVols;
end

%% evaluate obtained volumes

% no negative cash value
any(realWgts(:, 1) < 0)

% get squared deviations
lossFuncs = sum((realWgts - repmat(targetWgts, nDays, 1)).^2, 2);
plot(lossFuncs)

%%

area(realWgts)

%%

plot(stratVols)

%% get portfolio values

pfVals = sum(stratVols(:, 2:end) .* subPrices{:, 2:end}, 2) + stratVols(:, 1);

%%
plot(subPrices.Date, pfVals)
datetick 'x'
grid on
grid minor

%%

nYears = (subPrices.Date(end) - subPrices.Date(1))/365;

((pfVals(end) / pfVals(1)).^(1/nYears) - 1)*100

%% comparisong to individual annualized returns

((subPrices{end, 2:end} ./ subPrices{1, 2:end}).^(1/nYears) - 1)*100

%% plot return series

logRets = price2retWithHolidays(subPrices, true);

%%

desiredRows = 3;
nCols = ceil(nEtfs / desiredRows);
nRows = desiredRows;

for ii=1:nEtfs
    subplot(nRows, nCols, ii)
    plot(logRets.Date, logRets{:, ii+1}*100)
    datetick 'x'
    grid on
end

%% estimate GARCH(1,1)

% preallocation
volas = logRets;

garchSpec = garch(1, 1);

for ii=1:nEtfs
    garchHat = estimate(garchSpec, logRets{:, ii+1}*100);
    
    % get associated sigma series
    varHat = infer(garchHat, logRets{:, ii+1}*100);
    
    volas{:, ii+1} = sqrt(varHat);
end

%%

plot(volas.Date, volas{:, 2:end})
datetick 'x'
grid on
grid minor
legend(tabnames(subPrices(:, 2:end)))

%% Plot vola in ranks

rnkVolas = ranks(volas{:, 2:end});
subplot(2, 1, 1)
plot(volas.Date, rnkVolas)
datetick 'x'
grid on
grid minor
legend(tabnames(subPrices(:, 2:end)), 'Location', 'Southwest')

subplot(2, 1, 2)
plot(volas.Date, mean(rnkVolas, 2), '-k')
datetick 'x'
grid on
grid minor

%% plot moving averages

% preallocation
mvAvgs1 = logRets;
mvAvgs2 = logRets;

for ii=1:nEtfs
    [Short, Long] = movavg(logRets{:, ii+1}*100, 100, 300, 0);
    mvAvgs1{:, ii+1} = Short;
    mvAvgs2{:, ii+1} = Long;
end

%%
plot(mvAvgs1.Date, mvAvgs1{:, 2:end})
datetick 'x'
grid on
grid minor

%% plot moving averages of scaled returns

scaledRets = logRets;
scaledRets{:, 2:end} = logRets{:, 2:end}./volas{:, 2:end};

%% plot moving averages

% preallocation
mvAvgs1 = logRets;
mvAvgs2 = logRets;

for ii=1:nEtfs
    [Short, Long] = movavg(scaledRets{:, ii+1}, 100, 300, 0);
    mvAvgs1{:, ii+1} = Short;
    mvAvgs2{:, ii+1} = Long;
end

%%
subplot(2, 1, 1)
plot(mvAvgs1.Date, mvAvgs1{:, 2:end})
datetick 'x'
grid on
grid minor

subplot(2, 1, 2)
plot(mvAvgs2.Date, mvAvgs2{:, 2:end})
datetick 'x'
grid on
grid minor

%%

imagesc(corr(mvAvgs1{:, 2:end}), [-1 1])