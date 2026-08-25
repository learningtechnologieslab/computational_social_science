%% Seven Simple Models of the Quinoa Boom
% An introduction to modeling for computational social science
%
% MATLAB version. Requires core MATLAB only (no toolboxes), release R2018b or
% later. Run the sections in order with Ctrl+Enter (Cmd+Enter on a Mac).
%
% To read this as a formatted notebook with the figures inline, right-click the
% file in the Current Folder pane and choose "Open as Live Script".

%
% This script is built around a single piece of journalism:
%
% Jeremy Cherfas, _"Your Quinoa Habit Really Did Help Peru's Poor. But There's Trouble Ahead,"_ NPR (The Salt), 31 March 2016.
% https://www.npr.org/sections/thesalt/2016/03/31/472453674/your-quinoa-habit-really-did-help-perus-poor-but-theres-trouble-ahead
%
% *The story in brief.* Between 2006 and 2013 the world price of quinoa roughly tripled as North American and European shoppers discovered it. Journalists warned that Andean farmers were being priced out of their own food. Economists then went to the data (ENAHO, Peru's annual household survey of about 22,000 households) and found the warning was wrong: quinoa growers gained the most, urban buyers absorbed a small extra cost, and nobody's nutrition measurably worsened. But the article ends on three warnings: farmers abandoned most of the ~3,000 quinoa varieties, soil is degrading, and after February 2014 the price fell as fast as it had risen.
%
% *Why this article and not a dataset?* Because it is full of _verbal models_. Every claim in it is a compressed causal story:
% * "growers benefit"
% * "high prices attract competitors"
% * "soil is getting worse"
%
% A model is what you get when you make such a story precise enough to be wrong.

%% How to read this script if you don't write code
%
% You do not need to program to follow this. Read it like a set of illustrated arguments:
%
% # Read the *plain-language section* that opens each model. It states the claim from the article and the idea behind the model.
% # Skim the *code section*. Every line has a comment. The code is deliberately slow and repetitive -- written to be read, not to be efficient.
% # Look at the *picture* the code produces.
% # Read *"What to notice"* and try one of the *exercises*, which mostly mean changing a single number and re-running.
%
% A few pieces of vocabulary, once:
%
% * A *variable* is a name for a number: |price = 2.0| means "from now on, |price| refers to 2.0".
% * A *vector* is a named row of numbers, e.g. one value per year. A *table* is several of them side by side, with named columns.
% * A *loop* (|for i = 1:numel(years)|) means "do the following once for each year".
% * A *function* (|function w = welfare(...)|) is a named recipe you can re-use with different inputs.
% * A *parameter* is a number you choose that encodes an assumption. Parameters are where the modeling actually happens, and they are the honest place to argue.
%
% *To run a section:* click anywhere inside it and press |Ctrl+Enter| (|Cmd+Enter| on a Mac), or use the *Run Section* button in the Editor toolbar. Run the sections in order -- later ones depend on earlier ones. The next section sets up a few shared conventions. There is nothing to install: everything here uses core MATLAB, with no toolboxes.
%
% *Two things specific to MATLAB.* First, if you would rather read this as a formatted document with the pictures inline, right-click the file in the Current Folder pane and choose *Open as Live Script*; MATLAB converts it to a |.mlx| script. Second, MATLAB insists that any function defined inside a script must sit at the _end_ of the file. Models 4, 6 and 7 need functions, so theirs are collected in an appendix at the bottom. Each is signposted where it is used.

%% A note about all the numbers below
%
% * The _structures_ of these models are taken seriously.
% * The _numbers_ are illustrative, chosen so the pictures are legible and roughly consistent with the magnitudes quoted in the article.
% * None of this is a replication of the underlying papers by Bellemare, Gitter and Fajardo-Gonzalez, or by Stevens.
% * Treat every result as "here is what would follow *if* the world worked like this," never as an estimate of what actually happened.

% -------------------------------------------------------------------------
% SETUP. Run this section first. It only has to run once.
% -------------------------------------------------------------------------

% Everything below uses core MATLAB only. No toolboxes are required: where a
% model needs random numbers we build them from RAND and RANDN by hand rather
% than calling the Statistics and Machine Learning Toolbox.

clear; close all; clc

% A fixed "seed" for the random-number generator. Some models below use
% randomness; setting the seed means the random numbers are the SAME every time
% you run the script, so your figures match this text. Reproducibility is a
% methodological requirement, not a convenience.
rng(20160331)

% A named set of colours, so we can write TAB.green instead of an RGB triple.
% Each colour is three numbers (red, green, blue), each between 0 and 1.
TAB.blue   = [ 31 119 180]/255;
TAB.orange = [255 127  14]/255;
TAB.green  = [ 44 160  44]/255;
TAB.red    = [214  39  40]/255;
TAB.purple = [148 103 189]/255;
TAB.brown  = [140  86  75]/255;
TAB.grey   = [127 127 127]/255;
TAB.pale   = [223 230 236]/255;
TAB.steel  = [127 168 201]/255;

fprintf('Setup complete. Running MATLAB %s\n', version('-release'));

%% Model 1 -- The one-line model: who gains when a price rises?

%% The claim in the article
%
% The economist Marc Bellemare says he was not surprised by the finding, because in the short run someone who sells more of a good than they buy is better off when its price goes up.
%
% That sentence is a model. It has structure, it makes a prediction, and it can be checked. Let us write it down.

%% The idea
%
% Think of a household as doing two things with quinoa: *producing* some quantity (call it $q_{prod}$, in kilograms per year) and *consuming* some quantity ($q_{cons}$). The difference is what it trades:
%
% $$\text{net sales} = q_{prod} - q_{cons}$$
%
% If that number is positive the household is a *net seller*; if negative, a *net buyer*. Now let the price rise by $\Delta p$ soles per kilogram. To a first approximation, the change in the household's real income is
%
% $$\boxed{\Delta W \;\approx\; (q_{prod} - q_{cons}) \times \Delta p}$$
%
% That is the whole model. No computer required -- but a computer makes it easy to vary the assumptions.

%% Why "approximately"?
%
% Because the household will _respond_ to the new price: grow a bit more quinoa, eat a bit less, switch some spending. Those responses make the true gain slightly larger than the formula says for sellers, and the true loss slightly smaller for buyers. The formula is the value of the _first_ step, before anyone adjusts. Economists call this a first-order approximation; in more advanced courses it appears as the envelope theorem. For our purposes: it is accurate for small price changes and gets rougher as the change gets large -- and a tripling is not small. Hold that thought; it comes back in the discussion.

%% The households
%
% The article gives us enough to sketch three types. We use per-household figures for a household of four.
%
%  Type          Where      Produces  Eats  Budget
%  ------------  ---------  --------  ----  -----------------------
%  Grower-eater  Puno       yes       yes   poorer
%  Eater only    Lima etc.  no        yes   about twice as well off
%  Neither       Peru       no        no    --
%
% Two anchors from the article: quinoa is under *4%* of the household budget in Puno and under *0.5%* elsewhere; people in Puno ate about *22 kg per person per year* against a national average of about *6 kg*.

% -------------------------------------------------------------------------
% MODEL 1: net-seller welfare arithmetic
% -------------------------------------------------------------------------

% --- Assumptions (all the modeling lives here) ---------------------------
PRICE_BEFORE = 2.0;    % soles per kilogram, before the boom
PRICE_AFTER  = 6.0;    % soles per kilogram, after the tripling described in the article
PEOPLE       = 4;      % people per household

% Quinoa eaten per person per year, in kilograms (figures quoted in the article).
EAT_PUNO_PP     = 22.2;
EAT_NATIONAL_PP = 6.1;

% Turn per-person eating into per-household eating.
eatPuno     = EAT_PUNO_PP * PEOPLE;       % about 89 kg per household per year
eatNational = EAT_NATIONAL_PP * PEOPLE;   % about 24 kg per household per year

% We can BACK OUT each household's total budget from the budget shares in the
% article. If quinoa costs (eat x price) and that is 4% of the budget, then the
% budget must be (eat x price) / 0.04. This is a nice habit to notice: a share
% plus a level gives you the whole.
budgetPuno     = (eatPuno * PRICE_BEFORE) / 0.040;      % Puno: under 4% of budget
budgetNational = (eatNational * PRICE_BEFORE) / 0.005;  % elsewhere: under 0.5%

% How much a Puno grower harvests per year. This is the least well-anchored
% number in the model, so we will test how much it matters afterwards.
GROW_PUNO = 400.0;     % kilograms per household per year

% --- The three household types, as a table -------------------------------
% A "table" is MATLAB's labelled spreadsheet: one row per household type, one
% named column per fact about it. We can ask for households.budget later.
households = table( ...
    ["Grower-eater (Puno)"; "Eater only (urban)"; "Neither"], ...
    [GROW_PUNO;             0;                    0       ], ...
    [eatPuno;               eatNational;          0       ], ...
    [budgetPuno;            budgetNational;       budgetNational], ...
    'VariableNames', {'name', 'produces', 'eats', 'budget'});

% --- The model itself: one line ------------------------------------------
% An "anonymous function" is a formula with a name. The @(...) part lists what
% goes in; the rest is what comes out. Note the .* rather than *: the dot means
% "multiply element by element", so this works on one household or on a whole
% row of them at once.
welfareChange = @(produces, eats, priceChange) (produces - eats) .* priceChange;

priceChange = PRICE_AFTER - PRICE_BEFORE;   % +4 soles per kilogram

% MATLAB works on whole columns at once, so both answers come out in one line
% each: no loop is needed to fill in the table.
households.gain = welfareChange(households.produces, households.eats, priceChange);
households.pct  = 100 * households.gain ./ households.budget;

fprintf('Price rises from %.1f to %.1f soles/kg  (a change of %+.1f)\n\n', ...
        PRICE_BEFORE, PRICE_AFTER, priceChange);
fprintf('%-22s %10s %10s %10s %12s %10s\n', ...
        'household', 'grows', 'eats', 'net sales', 'gain (soles)', '% budget');
fprintf('%s\n', repmat('-', 1, 80));

for i = 1:height(households)
    fprintf('%-22s %10.0f %10.0f %10.0f %12.0f %+10.1f\n', ...
            households.name(i), ...
            households.produces(i), ...
            households.eats(i), ...
            households.produces(i) - households.eats(i), ...
            households.gain(i), ...
            households.pct(i));
end

% -------------------------------------------------------------------------
% Picture it, and then ask how much the shakiest assumption matters.
% -------------------------------------------------------------------------

figure('Position', [100 100 1000 400])

% --- Left panel: the gain for each household type, as % of its budget ----
subplot(1, 2, 1)
pcts = households.pct;

% Draw each bar separately so that we can colour them by sign. "hold on" means
% "keep what is already drawn and add to it".
hold on
for i = 1:numel(pcts)
    if pcts(i) > 0
        colour = TAB.green;
    elseif pcts(i) < 0
        colour = TAB.red;
    else
        colour = TAB.grey;
    end
    bar(i, pcts(i), 'FaceColor', colour)
end
yline(0, 'k-')                          % a line at zero, for reference
set(gca, 'XTick', 1:numel(pcts), 'XTickLabel', ...
    {'grower-eater', 'eater only', 'neither'})
ylabel({'change in real income', '(% of household budget)'})
title('Model 1: who gains from a tripling?')
xlim([0.4 numel(pcts) + 0.6])
grid on
hold off

% --- Right panel: SENSITIVITY ANALYSIS -----------------------------------
% We were unsure about how much a grower harvests. So instead of picking one
% number, try MANY and see what the model says for each. This is one of the most
% useful habits in modeling: never defend a number you can vary.
subplot(1, 2, 2)
harvests = linspace(0, 800, 200);       % 200 evenly spaced values, 0 to 800 kg
gainsPct = 100 * welfareChange(harvests, eatPuno, priceChange) / budgetPuno;

plot(harvests, gainsPct, 'LineWidth', 2, 'Color', TAB.blue)
hold on
yline(0, 'k-')
hRef = xline(eatPuno, '--'); hRef.Color = TAB.red;
text(eatPuno + 15, min(gainsPct) * 0.55, ...
     {'break-even:', 'grows exactly', 'what it eats'}, ...
     'Color', TAB.red, 'FontSize', 8)
xlabel('kilograms of quinoa harvested per year')
ylabel('change in real income (% of budget)')
title('How much does the harvest assumption matter?')
grid on
hold off

%% What to notice -- Model 1
%
% *The sign of the effect does not depend on any hard-to-measure number.* It depends only on whether the household grows more than it eats. Everything else -- the budget, the exact price, the elasticity of anything -- affects the _size_ of the answer, not its direction. That is a remarkably strong conclusion from a remarkably weak model, and it is why Bellemare could say he was unsurprised before seeing the data.
%
% *The loss for buyers is small because the budget share is small.* This is the quiet workhorse of the whole argument. Quinoa is culturally central in Puno but it is not rice: under 4% of the budget there, under 0.5% elsewhere. A tripling of a 0.5% budget item costs you about 1% of your budget. You cannot get a humanitarian catastrophe out of a line item that small -- which is the arithmetic the original scare stories skipped.
%
% *The model over-predicts the gain, and knowing why is the point.* Our grower's gain comes out implausibly large as a share of its budget. At least four reasons, each a modeling lesson:
%
% # *A tripling is not a small change*, so the first-order approximation is being used far outside its comfort zone.
% # *Farm-gate prices are not world prices.* Traders, processors and exporters capture part of the rise, so the $\Delta p$ facing the farmer is smaller than the one facing the shopper.
% # *Quinoa is not the household's only income*, so its budget denominator should include other crops, livestock and wage work.
% # *The relevant comparison is against what else the land would have grown.* Switching land into quinoa means giving up something, and the model silently prices that at zero.
%
% Each fix makes the model bigger. Deciding which fixes are worth the complication _is_ the craft.

%% Exercises -- Model 1
%
% # Set |GROW_PUNO = 60|. The household still grows less than it eats -- now it is a net buyer despite being a farmer. What happens to the sign? Which real households does this describe?
% # Change |PRICE_AFTER| to 8.0 (a quadrupling, as the article reports for Puno). Do any conclusions change qualitatively, or only in magnitude? Why does that distinction matter when you report results?
% # The model has no time in it. Write down, in words, one thing that happens over five years that this model must be getting wrong. (Then read Model 2.)

%% Model 2 -- Why farm prices overshoot: the cobweb

%% The claim in the article
%
% The price started falling in February 2014 and dropped about as fast as it had climbed, which the article treats as unsurprising: high prices attract competitors.
%
% Model 1 cannot produce that. It has no time in it: prices are just given. To get a _boom followed by a bust_ we need our first *dynamic* model -- one where this year's outcome depends on last year's.

%% The idea
%
% Agriculture has an unavoidable delay. A farmer decides in the spring how much to plant, and finds out at harvest what the price is. So the plausible assumption is that planting responds to *last year's* price:
%
% $$
% \begin{aligned}
% \text{how much is grown this year:} && Q^{S}_{t} &= c + d\, p_{t-1} \\
% \text{how much people want to buy:} && Q^{D}_{t} &= a - b\, p_{t}
% \end{aligned}
% $$
%
% Here $a, b, c, d$ are positive parameters: $b$ says how strongly buyers back off when the price rises, $d$ says how strongly farmers plant more when the price was high.
%
% Once the crop is in, the harvest is fixed and the price must move until the market clears, $Q^{D}_{t} = Q^{S}_{t}$. Solving for this year's price:
%
% $$\boxed{p_{t} = \frac{a - c - d\,p_{t-1}}{b}}$$
%
% Read the minus sign in front of $d$: *a high price last year means a low price this year.* Farmers responding sensibly to yesterday's news generate oscillation. Nobody has to be irrational.

%% The one thing worth remembering
%
% Because each year's price is $-d/b$ times the last one (plus a constant), the behaviour depends entirely on the ratio $d/b$:
%
% * $d/b < 1$ -- oscillations *shrink*; the market settles down.
% * $d/b = 1$ -- oscillations *persist* forever, unchanged.
% * $d/b > 1$ -- oscillations *grow*; the market flies apart.
%
% This is called a cobweb model, because of the shape it traces on a supply-and-demand diagram. It is one of the oldest formal models in economics, and it is the cleanest possible illustration of a general lesson: *delay plus negative feedback equals oscillation.* You will meet that lesson again in epidemics, in traffic, in inventory management, and in your own thermostat.

% -------------------------------------------------------------------------
% MODEL 2: the cobweb. A one-off jump in demand, three different farmer types.
% -------------------------------------------------------------------------

years = 2000:2025;      % a row of years: 2000, 2001, ... 2025

% --- Parameters ----------------------------------------------------------
DEMAND_SLOPE     = 8.0;     % "b": how much less is bought when the price rises by 1
SUPPLY_INTERCEPT = 20.0;    % "c": how much is grown even at a price of zero
DEMAND_BASE      = 100.0;   % "a" before the world discovered quinoa
DEMAND_JUMP      = 80.0;    % how much "a" rises when it becomes a superfood
BOOM_YEAR        = 2006;    % the year the jump happens

% A single permanent step up in demand. The comparison (y >= BOOM_YEAR) is
% either true or false, and MATLAB treats true as 1 and false as 0 - so this one
% line does the work of an if/else.
demandIntercept = @(y) DEMAND_BASE + DEMAND_JUMP * (y >= BOOM_YEAR);

% --- Run the same model three times with three different farmer responses -
% supplySlope is "d": how strongly farmers respond to last year's price.
scenarioLabels = {'Sluggish farmers:  d/b = 0.4', ...
                  'Responsive farmers: d/b = 0.9', ...
                  'Eager farmers:      d/b = 1.1'};
scenarioSlopes = [3.2, 7.2, 8.8];

figure('Position', [100 100 1200 380])

for k = 1:numel(scenarioSlopes)
    b = DEMAND_SLOPE;
    c = SUPPLY_INTERCEPT;
    d = scenarioSlopes(k);

    % Make an empty row of numbers, one slot per year, then fill it in.
    prices = zeros(1, numel(years));

    % Start the simulation at the calm long-run price of the OLD world, so that
    % anything interesting we see afterwards was caused by the demand jump and
    % not by an arbitrary starting point.
    prices(1) = (DEMAND_BASE - c) / (b + d);

    % Now step forward one year at a time. Each new price is computed from the
    % previous one using the boxed formula above.
    for i = 2:numel(years)
        a = demandIntercept(years(i));
        previousPrice = prices(i - 1);
        prices(i) = (a - c - d * previousPrice) / b;
    end

    % Keep the middle scenario for the next section to re-use.
    if k == 2
        pricesResponsive = prices;
    end

    subplot(1, 3, k)
    plot(years, prices, '-o', 'LineWidth', 1.5, 'MarkerSize', 3, ...
         'Color', TAB.blue, 'MarkerFaceColor', TAB.blue)
    hold on
    hRef = xline(BOOM_YEAR, '--'); hRef.Color = TAB.orange;

    % The price the market would eventually reach if there were no delay at all:
    longRun = (DEMAND_BASE + DEMAND_JUMP - SUPPLY_INTERCEPT) / (DEMAND_SLOPE + d);
    hRef = yline(longRun, ':'); hRef.Color = TAB.grey;

    xlabel('year')
    if k == 1
        ylabel('price (soles per kilogram)')
    end
    if k == 2
        text(BOOM_YEAR + 0.5, min(prices) + 0.5, 'demand jumps', ...
             'Color', TAB.orange, 'FontSize', 8)
    end
    title(scenarioLabels{k}, 'FontSize', 9)
    grid on
    hold off
end

sgtitle('Model 2: identical demand shock, three farmer response strengths')

fprintf('Dotted grey line = the price a delay-free market would settle at.\n');
fprintf('Note that all three panels have the same shock. Only d/b differs.\n');

% -------------------------------------------------------------------------
% Why it is called a "cobweb": the same simulation drawn on a supply-and-demand
% diagram instead of against time.
% -------------------------------------------------------------------------

d = 7.2;                         % the "responsive farmers" case
prices = pricesResponsive;       % computed in the previous section

% Look only at the years after the shock, when the interesting adjustment happens.
start = find(years == BOOM_YEAR);
pPath = prices(start:(start + 9));
aNew = DEMAND_BASE + DEMAND_JUMP;

figure('Position', [100 100 560 540])

% Draw the two curves. (They are straight lines here; economists still say "curves".)
pAxis   = linspace(min(pPath) - 1, max(pPath) + 1, 100);
qDemand = aNew - DEMAND_SLOPE * pAxis;
qSupply = SUPPLY_INTERCEPT + d * pAxis;

plot(qDemand, pAxis, 'LineWidth', 2, 'Color', TAB.blue)
hold on
plot(qSupply, pAxis, 'LineWidth', 2, 'Color', TAB.orange)

% Now trace the actual path the market takes, year by year, as a staircase:
% each year, quantity is set by LAST year's price (a horizontal move onto the
% supply curve), then price is set by THIS year's quantity (a vertical move onto
% the demand curve). Those two moves, repeated, draw the spiral.
for i = 1:(numel(pPath) - 1)
    qThisYear = SUPPLY_INTERCEPT + d * pPath(i);   % harvest, decided last year
    plot([qThisYear qThisYear], [pPath(i) pPath(i + 1)], ...
         'Color', TAB.red)                          % vertical: price adjusts
    qNextYear = SUPPLY_INTERCEPT + d * pPath(i + 1);
    plot([qThisYear qNextYear], [pPath(i + 1) pPath(i + 1)], ...
         'Color', TAB.red)                          % horizontal: planting adjusts
end

% Mark where the story starts, so the direction of travel is unambiguous.
plot(SUPPLY_INTERCEPT + d * pPath(1), pPath(2), 'ko', 'MarkerFaceColor', 'k')
text(SUPPLY_INTERCEPT + d * pPath(1) + 1.5, pPath(2), 'start (2006)', 'FontSize', 8)

xlabel('quantity')
ylabel('price')
title('The cobweb: a market spiralling inward to equilibrium')
legend({'demand: buyers this year', 'supply: planting response to last year'}, ...
       'Location', 'northeast', 'Box', 'off', 'FontSize', 8)
grid on
hold off

%% What to notice -- Model 2
%
% *Overshooting is normal, not evidence of a bubble.* The middle panel rises well above the price a frictionless market would have settled at, then falls back. No speculation, no manipulation, no irrationality, only a one-year planting delay. When you read a commodity price chart, "it overshot and crashed" is not by itself evidence that anything went wrong.
%
% *The same shock produces three different histories.* The demand jump is identical in all three panels. The only difference is how strongly farmers respond, and that single parameter decides whether the story is "market absorbs a shock," "market wobbles for a decade," or "market destabilises." If you were advising a government, $d/b$ is what you would want to know, and it is not visible in any price chart.
%
% *The model fails in an instructive way.* A _permanent_ rise in demand leaves the price permanently higher, so this model can produce a wobble around the new level but cannot bring the price nearly back to where it started -- which is what the article describes for late 2015. Something else must be going on, and the article names it: new producers in Arequipa with double the yields, plus China, India, Nepal, the United States and Canada planting quinoa. That is not a wobble in supply; it is a permanent expansion of it. That is Model 3.
%
% Noticing exactly which fact your model _cannot_ accommodate is more valuable than getting a good fit. It tells you what to build next.

%% Exercises -- Model 2
%
% # In |scenarioSlopes|, change 8.8 to 9.5. How many years until the model produces a negative price? What does an impossible prediction tell you about the _model_ rather than the world?
% # Real farmers probably do not look only at last year. Replace |previousPrice| with the average of the last two years and re-run. Does the market become more or less stable? Why might averaging stabilise things?
% # The cobweb assumes farmers never learn that their own collective response is what is crushing the price. Sketch, in words, what a model of farmers who _did_ learn would need. What would you need to know about them that a price series cannot tell you?

%% Model 3 -- Where the competitors came from: diffusion

%% The claim in the article
%
% High prices attract competitors. Coastal Arequipa, using intensive methods and fertiliser, got roughly double the yields of Puno; Peruvian exports overtook Bolivian ones; and China, India, Nepal, the United States and Canada started planting quinoa.

%% The idea
%
% New producers do not all appear at once, and they do not appear at a steady trickle either. Adoption of a new crop spreads the way rumours and diseases spread: slowly at first because few people are doing it, then fast as it becomes visible and imitable, then slowly again because almost everyone suitable has already adopted. The result is an *S-curve*, and the simplest model of it is the *logistic* equation:
%
% $$A_{t+1} = A_t + r\, A_t (1 - A_t)$$
%
% where $A_t$ is the fraction of potential new growers who have adopted (between 0 and 1) and $r$ sets the speed. Look at the two factors that multiply:
%
% * $A_t$ -- growth needs adopters to imitate. Nothing spreads from nobody.
% * $(1 - A_t)$ -- growth needs people left to convert. Nothing spreads to everybody twice.
%
% Their product is small at both ends and largest in the middle, which is exactly the S-curve. This same equation, under different names, models epidemics, technology adoption, language change, and viral content. Learning it once buys you a lot.

%% Coupling two models together
%
% Now for the step that makes this computational _social science_ rather than two separate exercises: we take the S-curve of adoption and feed it into the market from Model 2. Demand ramps up from 2006 to 2013 as in the article. Supply expands along the S-curve, arriving late. Price is whatever clears the market.
%
% Nobody wrote "and then the price crashes" into this model. It falls out.

% -------------------------------------------------------------------------
% MODEL 3: logistic adoption by new producers, feeding into the market
% -------------------------------------------------------------------------

years3 = 2000:2030;

% --- Demand side: a gradual ramp rather than Model 2's sudden jump -------
DEMAND_START = 100.0;    % demand intercept before the world discovers quinoa
DEMAND_END   = 180.0;    % ...and after
RAMP_FROM    = 2006;     % the years over which shoppers discover quinoa
RAMP_TO      = 2013;

% Before RAMP_FROM the fraction is 0, after RAMP_TO it is 1, and in between it
% slides linearly. MIN and MAX do the clamping, which avoids an if/else.
fractionDone    = @(y) min(1, max(0, (y - RAMP_FROM) / (RAMP_TO - RAMP_FROM)));
demandRamp      = @(y) DEMAND_START + (DEMAND_END - DEMAND_START) * fractionDone(y);

% --- Supply side: the S-curve of new entrants ----------------------------
SPREAD_RATE   = 0.7;      % "r": how fast adoption spreads
MIDPOINT_YEAR = 2014;     % the year adoption is halfway done (its steepest moment)
EXPANSION     = 0.50;     % if every potential entrant adopts, supply rises 50%
SUPPLY_FIXED  = 80.0;     % quantity from established Andean growers

% This is the closed-form solution of the logistic equation, which saves us a
% loop. It rises smoothly from ~0 to 1 with its steepest point at MIDPOINT_YEAR.
adoptedFraction = @(y) 1 ./ (1 + exp(-SPREAD_RATE * (y - MIDPOINT_YEAR)));

% --- Run it --------------------------------------------------------------
% Three empty rows of numbers, one slot per year, which the loop fills in.
adoption = zeros(1, numel(years3));
quantity = zeros(1, numel(years3));
price    = zeros(1, numel(years3));

for i = 1:numel(years3)
    year = years3(i);
    A = adoptedFraction(year);                  % how far adoption has spread
    Q = SUPPLY_FIXED * (1 + EXPANSION * A);     % total world supply this year
    a = demandRamp(year);                       % how keen buyers are this year
    p = (a - Q) / DEMAND_SLOPE;                 % the price that clears the market

    adoption(i) = A;
    quantity(i) = Q;
    price(i)    = p;
end

% --- Draw three stacked panels: cause, mechanism, consequence ------------
figure('Position', [100 100 800 760])

subplot(3, 1, 1)
plot(years3, demandRamp(years3), 'LineWidth', 2, 'Color', TAB.blue)
ylabel('demand strength')
title('Cause: Western shoppers discover quinoa (2006-2013)')
grid on

subplot(3, 1, 2)
plot(years3, 100 * adoption, 'LineWidth', 2, 'Color', TAB.green)
ylabel({'new growers who', 'have adopted (%)'})
title('Mechanism: adoption spreads along an S-curve, arriving late')
grid on

subplot(3, 1, 3)
plot(years3, price, 'LineWidth', 2, 'Color', TAB.red)
hold on
hRef = xline(2013, '--'); hRef.Color = TAB.grey;
text(2013.4, max(price) * 0.55, {'price peaks, then', 'new supply arrives'}, ...
     'FontSize', 8, 'Color', TAB.grey)
xlabel('year')
ylabel('price (soles/kg)')
title('Consequence: boom, then bust - which nobody put in by hand')
grid on
hold off

[peakPrice, peakIndex] = max(price);
fprintf('Price peaks in %d at %.1f, having started at %.1f.\n', ...
        years3(peakIndex), peakPrice, price(1));
fprintf('By %d it has fallen to %.1f - still above the old level, but well off the peak.\n', ...
        years3(end), price(end));

%% What to notice -- Model 3
%
% *The bust is not a separate event.* In this model the crash has the same cause as the boom. The high price is what made quinoa worth planting in Arequipa and Nepal; the planting is what ended the high price. There is no second shock, no policy failure, no villain. A system whose response to a signal destroys the signal is a *negative feedback loop with a delay*, and it is one of the two or three most common structures in all of social science.
%
% *Two models, one observation.* Model 2 and Model 3 both produce "price rises, then falls." They attribute it to completely different mechanisms: a planting lag among existing farmers, versus entry by new ones. Given only a price chart you _cannot_ tell them apart. This is called *equifinality* or the identification problem, and it is the single most important idea in this script. Fitting a curve to data does not establish a mechanism. To choose between these two models you would need different evidence entirely -- acreage by region, entry dates, who planted what and when.
%
% *Notice what we did not model.* Where does |MIDPOINT_YEAR = 2014| come from? We chose it, partly so the picture would resemble the article. That is fine for illustration and fatal for inference. A more honest model would make adoption _respond_ to the price rather than be scheduled by us (see the exercises), which is harder and much more interesting.

%% Exercises -- Model 3
%
% # Set |EXPANSION = 1.0| -- the new regions can double world supply rather than add half. What happens to the final price relative to the pre-boom price? What would that mean for a Puno farmer who took on debt in 2012?
% # Set |SPREAD_RATE = 0.25|. The crash becomes gentler and later. Which is worse for Andean farmers: a fast crash or a slow one? Notice that answering this requires a value judgement that the model does not contain.
% # *The interesting one.* Make adoption endogenous: instead of |adoptedFraction(year)|, grow |A| inside the loop using |A = A + r*A*(1 - A)*max(0, priceLastYear - threshold)|. Now high prices _cause_ adoption. You will need to keep track of last year's price. Does the boom-bust get sharper or smoother? This is the step from _describing_ a pattern to _explaining_ it.

%% Model 4 -- Soil, llamas and the cost of a good decade: a stock-and-flow model

%% The claim in the article
%
% A study by Adam Drucker's student Enrico Avitabile found that more than half of surveyed Bolivian farmers said their soil was worse than before the boom, for two reasons. High prices pulled land out of fallow, which had been letting it rest, causing erosion and nutrient loss. And farmers who earned more from quinoa cut back their llama herds -- so less manure was available to fertilise and protect the soil.
%
% Read that again and notice its shape. It is a *loop*: quinoa area up, pasture down, llamas down, manure down, soil down, and soil is what quinoa grows in.

%% The idea: stocks and flows
%
% Model 1 to 3 tracked prices and quantities -- things that happen in a year. This model tracks something different: a *stock*, a quantity that accumulates. Soil fertility is not an event, it is a bank balance. Each year some is deposited and some withdrawn, and what carries over is the balance.
%
% $$\text{stock next year} = \text{stock this year} + \text{inflows} - \text{outflows}$$
%
% Everything below is that one sentence, written three times. We track two stocks:
%
% *Soil fertility* $S$ (an index, 1.0 = pre-boom condition):
%
% $$S_{t+1} = S_t + \underbrace{g\,(1 - q_t)(S_{max} - S_t)}_{\text{resting land recovers}} + \underbrace{m\,L_t}_{\text{llama manure}} - \underbrace{k\, q_t}_{\text{cropping depletes}}$$
%
% *The llama herd* $L$, which grows toward whatever the remaining pasture can support:
%
% $$L_{t+1} = L_t + \rho\, L_t\left(1 - \frac{L_t}{K(1 - q_t)}\right)$$
%
% That is the logistic equation from Model 3 again -- but here it is doing a completely different job, describing a population pressing against a limit rather than an idea spreading. Reusing structure across domains is most of what modeling skill consists of.
%
% And the two are linked through a single decision: $q_t$, the fraction of land planted with quinoa, which rises when the price rises. Every kilogram of land in quinoa is a kilogram not in pasture.

%% What to watch for
%
% A stock can be run down for years while every annual report looks excellent. That is the whole point of building this model.

% -------------------------------------------------------------------------
% MODEL 4: coupled soil / herd / land-use dynamics
% -------------------------------------------------------------------------

years4 = 2000:2040;   % run well past the boom, to see the aftermath

% --- Parameters ----------------------------------------------------------
% We gather them into a "struct" - a single bundle of named numbers - because
% MATLAB's local functions cannot see the variables in this script. Anything a
% function needs must be handed to it, so bundling keeps the call tidy.
P.REGEN     = 0.10;      % "g":   how fast resting (fallow) land rebuilds fertility
P.MANURE    = 0.0225;    % "m":   fertility added per unit of llama herd
P.DEPLETION = 0.09;      % "k":   fertility removed per unit of land cropped
P.HERD_GROW = 0.35;      % "rho": how fast the herd grows toward what pasture allows
P.S_MAX     = 1.0;       % the best the soil gets: its pristine pre-boom condition
P.BASE_AREA = 0.25;      % fraction of land in quinoa at the normal price
P.RESPONSE  = 0.5;       % how strongly planting responds to price (0.5 = square-root)
P.years     = years4;

% These parameters are deliberately tuned so that at the pre-boom price the
% system sits STILL: inflows exactly balance outflows, soil stays at 1.0, herd
% stays at 1.0. That matters. It means anything we see later was caused by the
% boom and not by a slow drift we accidentally built in. Always establish that
% your model does nothing before you ask it to do something.

% runSoilModel is defined at the very bottom of this script, along with the
% price path and the planting rule it uses. See the closing section for why.
withDegradation    = runSoilModel(true,  P);
withoutDegradation = runSoilModel(false, P);

% --- Draw four panels: cause, land use, the stock, and the bill ----------
figure('Position', [100 100 1050 700])

subplot(2, 2, 1)
plot(years4, withDegradation.price, 'LineWidth', 2, 'Color', TAB.orange)
ylabel('price (multiple of pre-boom)')
title('The price shock we impose')
grid on

subplot(2, 2, 2)
plot(years4, 100 * withDegradation.area, 'LineWidth', 2, 'Color', TAB.brown)
hold on
plot(years4, 100 * withDegradation.herd * (1 - P.BASE_AREA), ...
     'LineWidth', 2, 'Color', TAB.purple)
ylim([20 80])
ylabel('% of land / relative herd size')
title('Land use responds; the herd is squeezed out')
legend({'land in quinoa', 'llama herd (scaled)'}, 'Location', 'northeast', ...
       'Box', 'off', 'FontSize', 8)
grid on
hold off

subplot(2, 2, 3)
plot(years4, withDegradation.soil, 'LineWidth', 2, 'Color', TAB.green)
hold on
hRef = yline(1.0, ':'); hRef.Color = TAB.grey;
% Pad the limits so the reference line at 1.0 is not hidden by the axis edge.
ylim([min(withDegradation.soil) - 0.005, 1.012])
xlabel('year')
ylabel('fertility index')
title('The stock: soil fertility does not come back')
grid on
hold off

subplot(2, 2, 4)
plot(years4, withDegradation.harvest, 'LineWidth', 2, 'Color', TAB.blue)
hold on
plot(years4, withoutDegradation.harvest, '--', 'LineWidth', 2, 'Color', TAB.orange)
xlabel('year')
ylabel('harvest (index)')
title('The bill arrives late, as lost output')
legend({'with degradation', 'counterfactual: soil indestructible'}, ...
       'Location', 'southeast', 'Box', 'off', 'FontSize', 8)
grid on
hold off

s       = withDegradation.soil;
hWith    = withDegradation.harvest;
hWithout = withoutDegradation.harvest;

fprintf('Soil fertility: 1.000 in 2000  ->  %.3f at the 2013 peak  ->  %.3f by 2040\n', ...
        s(14), s(end));
fprintf('Harvest in 2040: %.3f with degradation vs %.3f without - a shortfall of %.1f%%.\n', ...
        hWith(end), hWithout(end), 100 * (1 - hWith(end) / hWithout(end)));

%% What to notice -- Model 4
%
% *Every single year of the boom looks like a success.* Output rises, income rises, and it is all true. Meanwhile the stock is being drawn down, invisibly, because a stock is not in this year's accounts. This model does not contradict the good news from Model 1 -- it says the good news was measured over the wrong horizon. That combination, "the short-run finding is right _and_ the long-run picture is bad," is far more common in social science than either side of most public arguments admits.
%
% *Nothing recovers on its own.* When the price falls back to twice pre-boom levels, land use partly reverts and the herd partly recovers, but fertility settles at a permanently lower level. Stocks have memory. This is called *hysteresis*: the system does not retrace its path when you undo the shock. It is why "we can always reverse the policy later" is often a false promise.
%
% *The loop is the finding.* Any one of the three links -- more quinoa, fewer llamas, less manure -- is unremarkable on its own. Together they form a circuit that amplifies. You could not have found this by staring at correlations between pairs of variables; you find it by drawing the arrows and following them round.
%
% *Be honest about the parameters.* |DEPLETION = 0.09| is not measured; nobody handed us that number. So the _magnitudes_ in these figures mean nothing. What survives is the qualitative shape: delayed, partly irreversible decline that a boom-time income statement cannot see. Report the shape, not the digits.

%% Exercises -- Model 4
%
% # Set |P.MANURE = 0.0| -- imagine the herds vanish entirely. How much worse does the soil get? This is a crude way of asking how much of the damage runs through the llama channel rather than through fallow loss, and it is the kind of question a field study could then go and test.
% # Add a policy. Cap |plantedFraction| at 0.4 by changing the |min(0.85, ...)|. The farmer earns less during the boom and has better soil afterwards. Was the cap worth it? Notice you cannot answer without deciding how much you care about the future relative to the present -- a *discount rate*, and a moral choice wearing a technical costume.
% # Extend the model so that the _price_ also depends on total harvest, linking this to Model 2. You will have created a feedback loop with two delays. Predict before you run it whether that makes the system more or less stable.

%% Model 5 -- Why 3,000 varieties become five: a public-goods game

%% The claim in the article
%
% Export demand fastened onto a handful of the roughly 3,000 quinoa varieties, so farmers abandoned many of the rest. Stefano Padulosi argues those abandoned varieties are precisely what quinoa will need in order to adapt to pressures like climate change, and would like to see a global mechanism that rewards Andean farmers for maintaining diversity. Meanwhile Adam Drucker has run pilot studies on what it would take to persuade farmers to keep growing varieties exporters do not want -- and Gitter and Bellemare found that the 150 Puno farmers they interviewed would grow less-preferred varieties in exchange for cash.

%% The idea
%
% Models 1 to 4 had no _strategy_ in them. Prices moved and people responded. But this is a different kind of problem, because the value of diversity does not accrue to the farmer who maintains it. A rare variety that turns out to carry drought resistance benefits quinoa growers everywhere, for decades, including ones not yet born. The farmer who kept it alive captures almost none of that.
%
% This is the structure of a *public good*: costly to provide individually, valuable to everyone collectively, and therefore under-provided. It is the same skeleton as vaccination, tax compliance, fisheries, and emissions.

%% Part A: two farmers, four outcomes
%
% Strip it to two farmers, each choosing *Export variety* (high price) or *Traditional variety* (lower price, but adds to the shared stock of diversity):
%
% $$\text{payoff} = \underbrace{\text{private revenue from your own choice}}_{\text{yours alone}} + \underbrace{\text{value of diversity}}_{\text{shared by all, whoever provides it}}$$
%
% Watch what happens when each farmer asks the only question a payoff matrix lets them ask: _given whatever the other one does, what is best for me?_

% -------------------------------------------------------------------------
% MODEL 5A: the two-farmer diversity game
% -------------------------------------------------------------------------

% --- Parameters ----------------------------------------------------------
REVENUE_EXPORT      = 100.0;   % what you earn growing the variety exporters want
REVENUE_TRADITIONAL = 70.0;    % what you earn growing an old local variety
DIVERSITY_VALUE     = 20.0;    % value created for EVERYONE by each conserving farmer
% Note the tension deliberately built into these three numbers: conserving costs
% you 30 privately but creates 20 of value for EACH of the two farmers, i.e. 40
% in total. So conserving is good for the pair (40 > 30) and bad for you (20 < 30).

% STRCMP compares two pieces of text and returns true or false. MATLAB counts
% true as 1 and false as 0, so we can do arithmetic straight on the answer.
conserves = @(choice) strcmp(choice, 'Traditional');

% My private revenue depends only on my own choice.
privateRevenue = @(choice) REVENUE_TRADITIONAL * conserves(choice) + ...
                           REVENUE_EXPORT * (1 - conserves(choice));

% The public benefit depends on how many of us conserve - mine and theirs alike.
payoff = @(mine, other) privateRevenue(mine) + ...
                        DIVERSITY_VALUE * (conserves(mine) + conserves(other));

choices = {'Export', 'Traditional'};

fprintf('Payoffs (Farmer A, Farmer B). Rows = A''s choice, columns = B''s choice.\n\n');
fprintf('%-14s %22s %22s\n', '', 'B: Export', 'B: Traditional');
for ia = 1:2
    a = choices{ia};
    rowText = '';
    for ib = 1:2
        b = choices{ib};
        pair = sprintf('(%.0f, %.0f)', payoff(a, b), payoff(b, a));
        rowText = [rowText sprintf('%22s ', pair)];
    end
    fprintf('%-14s %s\n', ['A: ' a], rowText);
end

% --- Find the Nash equilibrium -------------------------------------------
% Definition: a pair of choices where NEITHER farmer can do better by switching,
% taking the other's choice as fixed. Let us just check all four possibilities.
fprintf('\nChecking each outcome for stability:\n');
for ia = 1:2
    for ib = 1:2
        a = choices{ia};
        b = choices{ib};
        otherA = choices{3 - ia};      % A's alternative
        otherB = choices{3 - ib};      % B's alternative
        aContent = payoff(a, b) >= payoff(otherA, b);   % would A rather switch?
        bContent = payoff(b, a) >= payoff(otherB, a);   % would B rather switch?
        if aContent && bContent
            verdict = 'NASH EQUILIBRIUM - nobody wants to move';
        else
            verdict = 'unstable';
        end
        fprintf('  A=%-12s B=%-12s -> total welfare %5.0f   %s\n', ...
                a, b, payoff(a, b) + payoff(b, a), verdict);
    end
end

bothExport   = 2 * payoff('Export', 'Export');
bothConserve = 2 * payoff('Traditional', 'Traditional');
fprintf('\nEveryone growing export varieties yields total welfare of %.0f.\n', bothExport);
fprintf('Everyone conserving would yield %.0f - which is %.0f higher, and unreachable.\n', ...
        bothConserve, bothConserve - bothExport);

%% What just happened -- Model 5
%
% Growing the export variety is a *dominant strategy*: it is better for you no matter what your neighbour does. So both farmers do it, and they land on the outcome that is worse for both. Nobody was greedy, short-sighted or ignorant. Each did the best available thing, and the aggregate was bad. That gap between individually sensible and collectively good is the reason this class of model exists -- and it is why the article's talk of a "global mechanism" is not hand-waving but a structural necessity. Exhortation cannot fix a dominant strategy. Changing the payoffs can.
%
% Which raises the practical question Drucker went out and asked: *how much cash would it take?*

%% Part B: paying for conservation
%
% Farmers differ. Some are almost indifferent between varieties; others would need a great deal to give up export revenue. Each farmer has a *willingness to accept* -- the smallest payment that would make conserving worth it. A farmer conserves if the payment offered is at least their willingness to accept.
%
% Below we simulate 150 farmers, matching the 150 Puno farmers in the Gitter and Bellemare interviews, and ask a designer's question: what does it cost to protect a target share of varieties? Then we compare two ways of paying, which turns out to matter a great deal.

% -------------------------------------------------------------------------
% MODEL 5B: how much would conservation cost?
% -------------------------------------------------------------------------

N_FARMERS = 150;     % matching the interview sample size mentioned in the article

% Each farmer's willingness to accept, in soles per year. We use a lognormal
% distribution: most farmers cheap, a few very expensive, none negative. That
% right-skewed shape is typical of real willingness-to-accept data, and choosing
% it is itself a modeling assumption you should be prepared to defend.
%
% A lognormal draw is just EXP applied to a normal one, so RANDN is all we need
% and no statistics toolbox is required.
MU    = log(300);    % sets the middle of the distribution: the median is 300
SIGMA = 0.8;         % sets how unequal the farmers are
wta   = exp(MU + SIGMA * randn(N_FARMERS, 1));

payments = linspace(0, 2000, 400);   % 400 candidate payment levels to test

uptake       = zeros(1, numel(payments));
costUniform  = zeros(1, numel(payments));
costTargeted = zeros(1, numel(payments));

for i = 1:numel(payments)
    offer       = payments(i);
    conserving  = wta <= offer;        % true/false for each farmer
    nConserving = sum(conserving);     % true counts as 1
    uptake(i)   = 100 * nConserving / N_FARMERS;

    % Way 1 - UNIFORM: advertise one price and pay it to everyone who accepts.
    % Simple, transparent, and you overpay every farmer who would have said yes
    % for less. That overpayment is called "rent".
    costUniform(i) = offer * nConserving;

    % Way 2 - TARGETED: pay each farmer exactly their own willingness to accept.
    % Cheaper, but it requires knowing a private number, which is precisely what
    % auctions and pilot schemes are trying to discover.
    costTargeted(i) = sum(wta(conserving));
end

figure('Position', [100 100 1050 400])

subplot(1, 2, 1)
histogram(wta, 30, 'FaceColor', TAB.blue, 'EdgeColor', 'white')
hold on
hRef = xline(median(wta), '--'); hRef.Color = TAB.red; hRef.LineWidth = 2;
yTop = max(ylim);
text(median(wta) * 1.15, yTop * 0.8, ...
     {'median', sprintf('%.0f soles', median(wta))}, 'Color', TAB.red, 'FontSize', 8)
xlabel('willingness to accept (soles per year)')
ylabel('number of farmers')
title('Farmers are not identical')
hold off

subplot(1, 2, 2)
plot(uptake, costUniform, 'LineWidth', 2, 'Color', TAB.blue)
hold on
plot(uptake, costTargeted, '--', 'LineWidth', 2, 'Color', TAB.orange)
xlabel('% of farmers conserving a traditional variety')
ylabel('total annual cost (soles)')
title('What conservation costs, and how you pay for it')
legend({'uniform payment to all takers', 'payment tailored to each farmer'}, ...
       'Location', 'northwest', 'Box', 'off', 'FontSize', 8)
grid on
hold off

% What does it cost to reach a 60% conservation target?
target = 60.0;
i = find(uptake >= target, 1);    % the first payment level that reaches the target

fprintf('To get %.0f%% of farmers conserving:\n', target);
fprintf('  offer                   : %6.0f soles per farmer per year\n', payments(i));
fprintf('  cost, uniform payment   : %6.0f soles per year\n', costUniform(i));
fprintf('  cost, tailored payment  : %6.0f soles per year\n', costTargeted(i));
fprintf('  overpayment (''rent'')     : %6.0f soles, or %.0f%% of the uniform bill\n', ...
        costUniform(i) - costTargeted(i), ...
        100 * (costUniform(i) - costTargeted(i)) / costUniform(i));

%% What to notice -- Model 5
%
% *The cost curve bends upward.* The first farmers are cheap, the last are dear, because you must raise the offer to reach the reluctant and that raise goes to everybody. So "conserve all 3,000 varieties" and "conserve most varieties" have wildly different price tags. Targets should be chosen with the cost curve in hand, not before.
%
% *How you pay can matter as much as how much.* The gap between the two lines is money that buys no additional conservation. In practice this is why conservation schemes experiment with auctions, in which farmers bid and the cheapest bids win -- an attempt to move from the upper line toward the lower one. The article's mention of pilot studies to work out what incentives farmers need is exactly this: not charity, but measurement of a distribution you cannot observe directly.
%
% *The article's ending now reads differently.* Drucker says the approach works and is cost-effective, and that the obstacle is unlocking public funds. Our model says why the obstacle exists: the beneficiaries are global and future, while the payers would be national and present. The mismatch is not a failure of will. It is in the structure of the payoffs.
%
% *A caution about the numbers.* Our 150 willingness-to-accept values came from a random number generator, not from Puno. The _shape_ of the argument is robust; the soles are fiction. Never let a simulated distribution be quoted as a finding.

%% Exercises -- Model 5
%
% # Change |SIGMA = 0.8| to |SIGMA = 0.3|, making farmers much more alike. What happens to the gap between uniform and tailored payment? Explain why heterogeneity is the thing that makes payment design matter.
% # In Part A, raise |DIVERSITY_VALUE| to 40 and lower |REVENUE_EXPORT| to 75. Does conserving become the dominant strategy? What real-world change would correspond to that shift in parameters?
% # The article mentions creating internal markets for threatened varieties, in hospital and school food programmes. Which parameter of Part A does that intervention change, and how does it differ from simply paying farmers?

%% Model 6 -- When a model fails usefully: demand with a subsistence floor

%% The claim in the article
%
% Andrew Stevens found that across Peru as a whole, quinoa eating fell from about 6.07 kg per person per year in 2004 to about 4.09 kg in 2012, following the price. But in Puno -- where more than 80% of Peru's quinoa is grown, and where prices rose even more steeply than nationally -- people ate slightly _more_: about 23.62 kg against 22.22 kg. Stevens reports that Puno households did not cut back despite a roughly fourfold price increase.
%
% Consumption rising while the price quadruples is the kind of fact that breaks textbook models. Good. This model is included because it *fails*, and because the failure is more instructive than any of the successes above.

%% Start with the standard model
%
% The simplest respectable demand model says people spend a fixed share $\alpha$ of their budget $m$ on quinoa. Then the quantity bought is
%
% $$q = \frac{\alpha\, m}{p}$$
%
% Quadruple the price, and consumption falls to a quarter. That is a strong prediction, and we can check it directly against Stevens's national numbers.

%% Then relax one assumption
%
% Now suppose there is some quantity of quinoa a household will hold onto almost regardless of price -- because it is what the children eat, because it is what the dishes require, because it is what food _is_ there. Call it $\gamma$, a habitual or subsistence floor. The household secures $\gamma$ first, then spends a share of whatever is left over the usual way:
%
% $$q = \gamma + \frac{\alpha}{p}\bigl(m - p\,\gamma\bigr)$$
%
% This is the *Stone-Geary* demand function, and it turns "quinoa is culturally important" from a piece of atmosphere into a number you can estimate and argue about. If $\gamma = 0$ it collapses back to the standard model, which is a good sign: a useful generalisation should contain the thing it generalises.
%
% We will do two things: find the floor that reproduces the national fall, then try to find one that reproduces the Puno rise.

% -------------------------------------------------------------------------
% MODEL 6: fitting a subsistence floorLevel to Stevens's two findings
% -------------------------------------------------------------------------

% --- The observations from the article -----------------------------------
NATIONAL.name = 'Peru as a whole';
NATIONAL.q2004 = 6.07;   NATIONAL.q2012 = 4.09;   NATIONAL.budgetShare = 0.005;

PUNO.name = 'Puno region';
PUNO.q2004 = 22.22;      PUNO.q2012 = 23.62;      PUNO.budgetShare = 0.040;

SG.PRICE_2004 = 2.0;      % soles per kilogram (an arbitrary but harmless scale)
SG.PRICE_2012 = 8.0;      % the roughly fourfold increase the article reports
SG.INCOME_GROWTH = 1.40;  % Peruvian living standards rose over this period; the
                         % article notes all three household groups saw their
                         % welfare rise.

% Both stoneGearyPrediction and analyse are defined at the bottom of the script.
national = analyse(NATIONAL, SG);
puno     = analyse(PUNO, SG);

for res = [national, puno]
    fprintf('%s\n', repmat('=', 1, 66));
    fprintf('%s\n', res.name);
    fprintf('  observed 2004 -> 2012            : %.2f -> %.2f kg per person\n', ...
            res.q2004, res.q2012);
    fprintf('  standard model (no floorLevel) predicts: %.2f kg\n', res.plain);
    fprintf('  best-fitting floorLevel               : %.2f kg, predicting %.2f kg\n', ...
            res.bestFloor, res.bestPrediction);
    fprintf('  remaining error                  : %.2f kg\n', res.bestError);
end
fprintf('%s\n', repmat('=', 1, 66));

% -------------------------------------------------------------------------
% Draw the fit for each region: how close can the model get, for any floorLevel?
% -------------------------------------------------------------------------

figure('Position', [100 100 1050 430])

results = [national, puno];
for k = 1:2
    res = results(k);
    subplot(1, 2, k)

    plot(res.floors, res.predictions, 'LineWidth', 2, 'Color', TAB.blue)
    hold on

    % IMPORTANT: YLINE does not stretch the axes to fit. The Puno observation
    % sits ABOVE every prediction, so we must include the reference values in
    % the limits or the red line would be invisible - and it is the whole point
    % of the panel.
    yAll = [res.predictions(:); res.q2012; res.q2004];
    ylim([min(yAll, [], 'omitnan') - 0.35, max(yAll, [], 'omitnan') + 0.75])

    hRef = yline(res.q2012, '--'); hRef.Color = TAB.red; hRef.LineWidth = 1.5;
    hRef = yline(res.q2004, ':'); hRef.Color = TAB.grey;

    % Mark the best fit only if the model can actually get close.
    if res.bestError < 0.15
        plot(res.bestFloor, res.bestPrediction, 'ko', 'MarkerFaceColor', 'k')
        labelX = max(res.floors) * 0.05;
        labelY = res.bestPrediction * 1.38;
        text(labelX, labelY, ...
             {sprintf('floorLevel = %.1f kg', res.bestFloor), 'fits exactly'}, 'FontSize', 8)
        % A plain line serves as the pointer from label to point.
        plot([labelX + max(res.floors) * 0.22, res.bestFloor * 0.96], ...
             [labelY * 0.97, res.bestPrediction * 1.04], 'k-')
    else
        % Point the line at the GAP: where the prediction stops short.
        gapY = 0.5 * (res.bestPrediction + res.q2012);
        plot([max(res.floors) * 0.45, max(res.floors) * 0.97], ...
             [res.q2012 * 0.62, gapY], 'k-')
        text(max(res.floors) * 0.03, res.q2012 * 0.55, ...
             {'the prediction line never', 'reaches the observation:', ...
              'NO floorLevel can explain this'}, 'Color', TAB.red, 'FontSize', 8)
    end

    xlabel('assumed subsistence floorLevel, gamma (kg per person per year)')
    ylabel('predicted 2012 consumption (kg)')
    title(res.name)
    legend({'model prediction for 2012', ...
            sprintf('observed 2012: %.2f kg', res.q2012), ...
            sprintf('observed 2004: %.2f kg', res.q2004)}, ...
           'Location', 'southeast', 'Box', 'off', 'FontSize', 7)
    grid on
    hold off
end

sgtitle('Model 6: one model, one success and one honest failure')

%% What to notice -- Model 6
%
% *The standard model gets the national direction right and the magnitude badly wrong.* It predicts consumption collapsing to roughly a third of what was actually observed. Directionally correct, quantitatively useless -- a distinction worth insisting on, because a great deal of published social science stops at the direction.
%
% *A floor of about 3 kg per person fits the national data exactly.* That is a real finding of sorts: it converts the vague phrase "culturally important" into "roughly 3 kg a year that Peruvians will not give up." Now it is a claim someone can go and test against other evidence, which is the entire point of writing a model down.
%
% *And for Puno, no floor works at all.* Look at the right-hand panel. As the assumed floor rises, the prediction climbs toward the 2004 level and stops -- it can approach 22.22 kg and never exceed it. But Puno ate _more_ in 2012 than in 2004. The gap does not shrink to zero for any parameter value. *The model is not mis-calibrated; it is mis-specified.* No amount of fitting will save it.
%
% That is a genuinely valuable result, and here is why. When a model can be tuned to match anything, matching tells you nothing. This one _cannot_ match, which means it has real content, and its failure points at specific missing mechanisms:
%
% # *Puno households are producers.* Their income rises _with_ the quinoa price, in exactly the way Model 1 described. Our model treated income as independent of price, which is wrong precisely where quinoa is grown.
% # *Other prices moved too.* The article reports a hint that Puno households cut back on high-fat foods to keep eating quinoa. A one-good model cannot represent substitution _between_ foods, and substitution is evidently what happened.
% # *Much of it was never bought.* Farmers eat their own harvest. What a market price means for a household that grows the good is a genuinely difficult question in survey economics, and our model quietly assumed every kilogram was purchased at the market price.
%
% A one-good, fixed-income model was never going to survive contact with a region that grows 80% of the crop. Discovering that by watching it fail, rather than by being told, is the lesson.

%% Exercises -- Model 6
%
% # Set |SG.INCOME_GROWTH = 1.0| (no rise in living standards) and re-run. How much of the national story was price and how much was income? This is a *decomposition*, and it is one of the most common things applied modelers do.
% # Modify |analyse| so that for Puno the 2012 budget also includes quinoa sales revenue, which rises with the price: add something like |+ 100*SG.PRICE_2012| to |budget2012|. Can the model now reproduce the Puno increase? What have you had to assume about how much they sell?
% # *A conceptual question.* We rejected the model because it could not fit. But we chose the fourfold price rise, the 40% income growth, and the budget shares ourselves. How would you distinguish "the model is wrong" from "our inputs are wrong"? There is no fully satisfying answer, and knowing that is important.

%% Model 7 -- Modeling the story itself: how a false claim travelled

%% The claim in the article
%
% The article's own framing is that scary media reports circulated, and that even when people working on the ground tried to explain that buying quinoa was helping Andean farmers, what they had was anecdote rather than evidence. The evidence arrived years later, in working papers using ten years of ENAHO data.
%
% For a course in _computational social science_, this is the most interesting model in the script -- because the object being modeled is the discourse, not the market.

%% The idea
%
% A claim spreading through a population behaves much like an infection. At any moment, divide people into three groups:
%
% * *S* -- has not encountered the claim yet
% * *B* -- encountered it, believes it, repeats it to others
% * *R* -- has stopped repeating it, whether from boredom or from having seen the correction
%
% The flows between them:
%
% $$
% \begin{aligned}
% \text{new believers} &= \beta \, S \, B \quad \text{(a believer meets a susceptible)} \\
% \text{people who drop it} &= \delta \, B
% \end{aligned}
% $$
%
% The product $S \times B$ is the crucial term. It says transmission needs _both_ someone to spread and someone to spread to -- the same structure as the logistic in Models 3 and 4, now doing a third job. If you have followed this script you have now seen one mathematical form model an idea spreading, a herd of llamas hitting a limit, and a rumour propagating. That transferability is not a coincidence and it is not a trick; it is the reason formal modeling earns its keep across fields that share no subject matter.

%% The question worth asking
%
% The article's implicit criticism is about _timing_: the claim ran unopposed for years before anyone checked. So we run the same epidemic twice, changing only when the correction arrives, and ask what the correction buys.

% -------------------------------------------------------------------------
% MODEL 7: the spread of a claim, and the arrival of evidence
% -------------------------------------------------------------------------

E.MONTHS = 72;              % six years, roughly 2010 to 2016
E.STEP   = 0.25;            % we advance in quarter-month steps for smoothness

E.TRANSMISSION    = 0.42;   % "beta":  how readily the claim passes on
E.FORGETTING      = 0.05;   % "delta": how fast people drop it unprompted
E.EVIDENCE_EFFECT = 8.0;    % how much faster people drop it once evidence lands
E.SEED_SHARE      = 0.002;  % the tiny fraction who believe it at the very start

% Two worlds: evidence at 12 months, and evidence at 42 months.
% runEpidemic is defined at the bottom of the script.
early = runEpidemic(12, E);
late  = runEpidemic(42, E);

figure('Position', [100 100 1050 430])

runs   = {early, late};
whens  = [12, 42];
titles = {'Evidence published early (month 12)', ...
          'Evidence published late (month 42)'};

for k = 1:2
    state = runs{k};
    subplot(1, 2, k)

    % AREA piles the three groups on top of one another by default,
    % which is exactly the picture we want: the whole population, divided up.
    h = area(state.t, 100 * [state.S, state.B, state.R], 'LineStyle', 'none');
    h(1).FaceColor = TAB.pale;      % never heard it
    h(2).FaceColor = TAB.red;       % believes and repeats it
    h(3).FaceColor = TAB.steel;     % no longer repeats it
    hold on

    hRef = xline(whens(k), 'k--'); hRef.LineWidth = 1.5;
    text(whens(k) + 1, 88, {'evidence', 'arrives'}, 'FontSize', 8)

    xlabel('months')
    if k == 1
        ylabel('% of population')
        legend({'never heard it', 'believes and repeats it', 'no longer repeats it'}, ...
               'Location', 'west', 'Box', 'off', 'FontSize', 8)
    end
    title(titles{k}, 'FontSize', 9)
    ylim([0 100])
    xlim([0 E.MONTHS])
    hold off
end

sgtitle('Model 7: the same claim, corrected early and corrected late')

% How many people ever believed it? That is everyone who left S: 1 minus the
% fraction still in S at the end.
names = {'early correction', 'late correction'};
for k = 1:2
    state = runs{k};
    ever = 100 * (1 - state.S(end));
    [peak, peakIndex] = max(state.B);
    fprintf('%-18s: %5.1f%% ever believed it | peak %4.1f%% believing at once, in month %.0f\n', ...
            names{k}, ever, 100 * peak, state.t(peakIndex));
end

%% What to notice -- Model 7
%
% *Correcting the record late barely reduces how many people ever believed it.* In the late-evidence world, almost everyone has already passed through the believing state before the papers appear. The correction changes what people believe _now_; it cannot change what they believed for three years, or the decisions they made meanwhile -- the shoppers who stopped buying quinoa out of conscience, and whose purchases, on the evidence in the article, were helping the people they were worried about.
%
% *Timing beats content.* This model has no term at all for how _convincing_ the evidence is. It does not need one. The arrival date alone drives most of the difference. That is an uncomfortable result for anyone who believes better arguments win, and it is why "rapid response" and pre-registered data infrastructure are treated as serious epistemic institutions rather than public relations.
%
% *The debunking never fully wins.* Notice that the pale grey "never heard it" band never disappears, and believers linger. In this model, as in reality, some people simply never encounter the correction. Retractions travel through a smaller network than the original claim.
%
% *A caveat you should always attach to this model.* The epidemic analogy imports assumptions that may not hold for ideas: that everyone mixes with everyone, that believing is a single binary state, that hearing the correction is like recovering from an illness. Real beliefs are held in networks, with degrees of conviction, and with motivated resistance. The right response is not to abandon the model but to know which of its conclusions depend on the shaky assumptions. Here, "late corrections are weak" is robust across almost any variant. Specific percentages are not.

%% Exercises -- Model 7
%
% # Find, by trial and error, the latest month at which the correction still keeps the eventual believer share under half. Is that a realistic timescale for academic publication? What would it take to hit it?
% # Set |EVIDENCE_EFFECT = 30|, making the debunking overwhelmingly persuasive, and keep it late. Compare to an early but weak correction (|runEpidemic(12, E)|, |EVIDENCE_EFFECT=2|). Which does better? What does that imply about where to invest?
% # *The hard one.* This model treats the true and false claims symmetrically -- both are just claims that spread. Is there anything in the structure that would make truth spread better? If not, what does that suggest about relying on the marketplace of ideas?

%% Coda -- Two different things called "models"
%
% Everything above is a *mechanistic* model: we specified how we think the world works, and derived what would follow. But the papers the article reports do something else entirely. Bellemare, Gitter and Fajardo-Gonzalez cleaned ten years of ENAHO data covering the boom and the years before it, split households into three groups -- those who grow and eat quinoa, those who eat but do not grow it, and those who do neither -- and compared how each group's welfare moved as the price rose. That is a *statistical* model. It does not say why anything happens. It asks whether a pattern in observed data could plausibly have arisen by chance.
%
% Both are called models. They answer different questions and they fail in different ways. A mechanistic model can be beautifully coherent and describe no world that exists. A statistical model can be perfectly estimated and mean nothing, because a difference between groups is not automatically an effect.
%
% The specific difficulty in this case is one the article steps around in a single sentence: quinoa eaters who do not grow it are roughly twice as well off as growers. So if you simply compared growers and non-growers _after_ the boom, growers would look worse off -- not because the boom hurt them but because they were poorer to begin with. The comparison you want is not between groups but between _changes_ in groups. Below is a small simulation of that idea, called *difference-in-differences*, which is the workhorse of applied social science.
%
% We generate fake households where we _know_ the true answer, and then check whether the method recovers it. That is the only situation in which you can ever validate a statistical method, and it is why simulation belongs in a methods course.

% -------------------------------------------------------------------------
% CODA: why you compare changes, not levels
% -------------------------------------------------------------------------

N = 4000;                     % households in our synthetic survey
TRUE_EFFECT = 500.0;          % the real gain to growers from the boom, in soles.
                              % We KNOW this because we are about to create it.

% Half the households grow quinoa. Growers are poorer to start with - this is the
% fact from the article that makes naive comparison misleading.
isGrower = rand(N, 1) < 0.5;
baselineWelfare = 9600.0 - 4800.0 * isGrower;

% Everyone's welfare rises over the period, because Peru grew. The article is
% explicit that all three groups saw living standards improve.
COMMON_TREND = 900.0;

% Survey noise: every household is idiosyncratic, and surveys are imperfect.
% RANDN gives standard normal numbers, which we scale to the spread we want.
NOISE_SD = 1200.0;
noiseBefore = NOISE_SD * randn(N, 1);
noiseAfter  = NOISE_SD * randn(N, 1);

welfareBefore = baselineWelfare + noiseBefore;
welfareAfter  = baselineWelfare + COMMON_TREND + TRUE_EFFECT * isGrower + noiseAfter;

% --- The wrong comparison: growers vs non-growers, after the boom only ----
% The "~" means "not", so ~isGrower picks out the non-growers.
naive = mean(welfareAfter(isGrower)) - mean(welfareAfter(~isGrower));

% --- The right comparison: how much each group CHANGED -------------------
changeGrowers    = mean(welfareAfter(isGrower))  - mean(welfareBefore(isGrower));
changeNonGrowers = mean(welfareAfter(~isGrower)) - mean(welfareBefore(~isGrower));
did = changeGrowers - changeNonGrowers;    % difference in the differences

fprintf('True effect of the boom on growers      : %+8.0f soles\n', TRUE_EFFECT);
fprintf('%s\n', repmat('-', 1, 58));
fprintf('Naive comparison of levels after the boom: %+8.0f soles  <-- badly wrong, wrong sign\n', naive);
fprintf('Change among growers                     : %+8.0f soles\n', changeGrowers);
fprintf('Change among non-growers                 : %+8.0f soles\n', changeNonGrowers);
fprintf('Difference-in-differences estimate       : %+8.0f soles  <-- close to the truth\n', did);

% --- Picture it ----------------------------------------------------------
figure('Position', [100 100 640 420])

growerLine    = [mean(welfareBefore(isGrower)),  mean(welfareAfter(isGrower))];
nonGrowerLine = [mean(welfareBefore(~isGrower)), mean(welfareAfter(~isGrower))];

% The dashed line shows where growers WOULD have ended up with only the common
% trend and no boom effect. The gap between it and reality is the estimate.
counterfactual = mean(welfareBefore(isGrower)) + changeNonGrowers;

plot([0 1], growerLine, '-o', 'LineWidth', 2.5, 'Color', TAB.blue, ...
     'MarkerFaceColor', TAB.blue)
hold on
plot([0 1], nonGrowerLine, '-o', 'LineWidth', 2.5, 'Color', TAB.orange, ...
     'MarkerFaceColor', TAB.orange)
plot([0 1], [mean(welfareBefore(isGrower)), counterfactual], '--', ...
     'LineWidth', 1.5, 'Color', TAB.grey)

% A double-headed arrow marking the gap that the method estimates.
plot([1 1], [counterfactual, growerLine(2)], 'LineWidth', 1.8, 'Color', TAB.red)
plot(1, counterfactual, 'v', 'Color', TAB.red, 'MarkerFaceColor', TAB.red, 'MarkerSize', 5)
plot(1, growerLine(2), '^', 'Color', TAB.red, 'MarkerFaceColor', TAB.red, 'MarkerSize', 5)
text(1.03, (growerLine(2) + counterfactual) / 2, {'this gap is', 'the estimate'}, ...
     'Color', TAB.red, 'FontSize', 8)

xlim([-0.15 1.35])
set(gca, 'XTick', [0 1], 'XTickLabel', {'before the boom', 'after the boom'})
ylabel('average welfare (soles)')
title('Coda: growers stay poorer in levels, yet gain more')
legend({'quinoa growers (poorer, gain more)', 'non-growers (richer, gain less)', ...
        'growers'' counterfactual path'}, 'Location', 'west', 'Box', 'off', 'FontSize', 7)
grid on
hold off

%% What to notice -- Coda
%
% *Levels and changes can point in opposite directions.* The naive comparison says growers are far worse off; the correct one says the boom helped them. Both statements about the data are true. Only one of them answers the question asked. Most bad quantitative social science is not arithmetic error -- it is a well-computed answer to a question nobody asked.
%
% *The dashed line is doing all the work.* Difference-in-differences rests on an assumption you cannot observe: that without the boom, growers' welfare would have moved _parallel_ to non-growers'. If Andean agriculture was on a different trajectory for unrelated reasons -- weather, roads, migration -- the estimate is wrong and nothing in the data will tell you so. Every credible study of this type spends most of its length defending that assumption.
%
% *"It is a beast to work with."* Bellemare's remark about ENAHO deserves its place in a methods course. Someone -- Johanna Fajardo-Gonzalez, named in the article -- spent months cleaning ten years of survey data before any of this could be estimated. That labour is invisible in the published result and is usually the difference between a real finding and a spurious one.

%% Closing synthesis: what the seven models add up to
%
%  #   Model                      Type                    The idea it teaches
%  --  -------------------------  ----------------------  ---------------------------------------------------
%  1   Net-seller welfare         Static accounting       A model with no computation can overturn a headline
%  2   Cobweb                     Deterministic dynamics  Delay plus negative feedback produces oscillation
%  3   Logistic diffusion         Coupled dynamics        Equifinality: one pattern, many possible mechanisms
%  4   Soil and herds             Stock and flow          Stocks have memory; good years can hide a drawdown
%  5   Diversity game             Strategic interaction   Individually rational, collectively bad
%  6   Demand with a floor        Calibration and fit     A model that cannot fit is a model with content
%  7   Spread of a claim          Contagion               Timing can dominate truth
%  --  Difference-in-differences  Statistical inference   Compare changes, not levels
%
% Four things to take from putting them side by side.
%
% *No model is the model.* Seven models of one article, all defensible, several mutually inconsistent about mechanism. A model is not a small copy of the world; it is an instrument for asking one question at a time. Choosing which question is the researcher's job, and no algorithm does it for you.
%
% *Simple models earn their keep by being wrong in visible places.* Model 1 is almost embarrassingly crude and it settles the central dispute. Model 6 fails and the failure locates a real mechanism. A large simulation with forty parameters fitted to the same data would have told you less, because when everything can be adjusted, nothing is tested.
%
% *Time horizon is a modeling choice with moral weight.* Models 1 and 4 do not disagree about facts. They disagree about when to stop counting. "Was the quinoa boom good?" cannot be answered without saying good _by when_, and that is not something the data decides.
%
% *Mechanism and measurement need each other.* The mechanistic models above generate hypotheses but cannot say what happened. The statistical work in the papers establishes what happened but not why. Computational social science, done well, is the practice of holding both and refusing to let either off the hook.

%% Suggested assignment
%
% Pick any _one_ sentence from the article that we did not model. Then:
%
% # State the causal claim inside it in one sentence.
% # Write the smallest model that could be wrong about it -- no more than about fifteen lines of code.
% # Identify the one parameter your conclusion is most sensitive to, and say honestly how you would go about measuring it.
% # Name one fact that your model cannot accommodate, and say what you would build next.
%
% Step 4 is worth the most marks.

%% Appendix: the local functions
%
% MATLAB requires that functions defined inside a script appear after all of the script's executable code. That is a language rule, not a stylistic choice, and it is the one place where this version cannot follow the same reading order as the rest. Everything below belongs to Models 4, 6 and 7, and is commented exactly as it would be if it sat beside its own model.
%
% Note also that these functions cannot see the variables in the script. Anything they need is passed in, which is why Models 4, 6 and 7 gather their parameters into a bundle (|P|, |SG| and |E|) first.

% -------------------------------------------------------------------------
% Model 4's three pieces
% -------------------------------------------------------------------------

function p = relativePrice(year)
% The price story, taken from the article: rise to 2013, fall by 2016.
% Expressed as a multiple of the pre-boom price, so 1.0 = "normal", 4.0 = "quadrupled".
if year < 2006
    p = 1.0;
elseif year <= 2013
    p = 1.0 + 3.0 * (year - 2006) / 7.0;    % climb from 1x to 4x
elseif year <= 2016
    p = 4.0 - 2.0 * (year - 2013) / 3.0;    % fall from 4x to 2x
else
    p = 2.0;                                 % settle at twice pre-boom
end
end

function q = plantedFraction(price, P)
% Farmers plant more when the price is high, with diminishing enthusiasm,
% and can never plant more than 85% of their land.
q = min(0.85, P.BASE_AREA * price ^ P.RESPONSE);
end

function out = runSoilModel(soilCanDegrade, P)
% If soilCanDegrade is false we hold fertility fixed at 1.0. That gives us a
% COUNTERFACTUAL: the same boom in a world where soil were indestructible.
% Comparing the two isolates the cost of degradation.
soil = 1.0;
herd = 1.0;

years = P.years;
n = numel(years);

% Prepare empty rows of numbers, one slot per year, then fill them in.
out.year    = years;
out.price   = zeros(1, n);
out.area    = zeros(1, n);
out.soil    = zeros(1, n);
out.herd    = zeros(1, n);
out.harvest = zeros(1, n);

for i = 1:n
    year    = years(i);
    price   = relativePrice(year);
    q       = plantedFraction(price, P);   % land in quinoa
    pasture = 1.0 - q;                     % land left for llamas
    yieldPerUnit = soil;                   % fertile soil grows more per hectare
    harvest = q * yieldPerUnit;            % this year's output

    out.price(i)   = price;
    out.area(i)    = q;
    out.soil(i)    = soil;
    out.herd(i)    = herd;
    out.harvest(i) = harvest;

    % --- Update the two stocks: balance = balance + in - out --------------
    if soilCanDegrade
        recovery   = P.REGEN * pasture * (P.S_MAX - soil);   % resting land rebuilds
        fertiliser = P.MANURE * herd;                        % manure from llamas
        loss       = P.DEPLETION * q;                        % cropping takes nutrients
        soil = min(P.S_MAX, max(0.05, soil + recovery + fertiliser - loss));
    end

    capacity = max(pasture / (1.0 - P.BASE_AREA), 1e-6);     % pasture sets the ceiling
    herd = max(0.02, herd + P.HERD_GROW * herd * (1.0 - herd / capacity));
end
end

% -------------------------------------------------------------------------
% Model 6's two pieces
% -------------------------------------------------------------------------

function q = stoneGearyPrediction(floorLevel, qStart, priceStart, priceEnd, ...
                                  budgetStart, budgetEnd)
% Step 1: work out the household's marginal budget share "alpha" from the
% fact that it consumed qStart when the price was priceStart. This is
% called CALIBRATION: we do not guess alpha, we solve for the value that
% makes the model exactly reproduce the starting point.
spareBudget = budgetStart - priceStart * floorLevel;    % money left after the floorLevel
if spareBudget <= 0 || qStart <= floorLevel
    q = NaN;                                        % this floorLevel is impossible
    return
end
alpha = (qStart - floorLevel) * priceStart / spareBudget;

% Step 2: with alpha fixed, predict consumption at the new price and income.
spareLater = budgetEnd - priceEnd * floorLevel;
if spareLater <= 0
    q = NaN;
    return
end
q = floorLevel + (alpha / priceEnd) * spareLater;
end

function res = analyse(region, SG)
% Recover the household budget from the budget share quoted in the article.
budget2004 = region.q2004 * SG.PRICE_2004 / region.budgetShare;
budget2012 = budget2004 * SG.INCOME_GROWTH;

% First: the standard model, i.e. a floorLevel of exactly zero.
plain = stoneGearyPrediction(0.0, region.q2004, SG.PRICE_2004, SG.PRICE_2012, ...
                             budget2004, budget2012);

% Then: try every floorLevel from 0 up to just below what they already eat, and
% see which one comes closest to the observed 2012 figure. This is a "grid
% search" - the least clever and most transparent way to fit a parameter.
floors = linspace(0, region.q2004 * 0.999, 2000);

% ARRAYFUN applies a function to every element of a row of numbers and
% collects the answers, which saves writing another loop.
predictions = arrayfun(@(f) stoneGearyPrediction(f, region.q2004, SG.PRICE_2004, ...
                       SG.PRICE_2012, budget2004, budget2012), floors);

errors = abs(predictions - region.q2012);
[bestError, best] = min(errors);   % MIN quietly ignores the impossible (NaN) floors

res = region;                      % keep the name and the observations
res.budget2004     = budget2004;
res.plain          = plain;
res.floors         = floors;
res.predictions    = predictions;
res.errors         = errors;
res.bestFloor      = floors(best);
res.bestPrediction = predictions(best);
res.bestError      = bestError;
end

% -------------------------------------------------------------------------
% Model 7's one piece
% -------------------------------------------------------------------------

function out = runEpidemic(evidenceMonth, E)
% Three compartments, as fractions of the population, adding to 1.
S = 1.0 - E.SEED_SHARE;
B = E.SEED_SHARE;
R = 0.0;

% How many steps we will take, and empty columns to record each one.
nSteps = floor(E.MONTHS / E.STEP);
out.t = zeros(nSteps, 1);
out.S = zeros(nSteps, 1);
out.B = zeros(nSteps, 1);
out.R = zeros(nSteps, 1);

t = 0.0;
for i = 1:nSteps
    % Has the debunking evidence been published yet? If so, people abandon
    % the claim much faster. Note we model evidence as changing a RATE, not
    % as instantly convincing everyone - which is the realistic version.
    dropRate = E.FORGETTING;
    if t >= evidenceMonth
        dropRate = E.FORGETTING * E.EVIDENCE_EFFECT;
    end

    % The flows during this small slice of time.
    newlyConvinced = E.TRANSMISSION * S * B * E.STEP;
    newlyDropped   = dropRate * B * E.STEP;

    % Move people between compartments. Whatever leaves S enters B, and
    % whatever leaves B enters R. Nobody is created or destroyed - a useful
    % thing to check in any model of this kind.
    S = S - newlyConvinced;
    B = B + newlyConvinced - newlyDropped;
    R = R + newlyDropped;

    out.t(i) = t;
    out.S(i) = S;
    out.B(i) = B;
    out.R(i) = R;

    t = t + E.STEP;
end
end
