%% Naive Bayes in MATLAB: Three Worked Examples
% *Computational Social Science - Lecture 4 companion*
%
% This is the MATLAB counterpart to the Python/scikit-learn and R versions. It builds
% Naive Bayes classifiers three times, at increasing scale:
%
% * *Example 1* - Weather & golf, from the lecture slides. 14 rows, 1 categorical
%   predictor. Verifies that the library reproduces the hand calculation.
% * *Example 2* - Voter turnout, from the lecture slides. 14 rows, 3 categorical
%   predictors. Where the independence assumption enters; the zero-frequency problem.
% * *Example 3* - Income and inequality. Real data: the 1994 US Census "Adult" extract,
%   ~32,500 rows, 12 engineered predictors. A full applied workflow and its limits.
%
% HOW TO RUN THIS
%   Open in the MATLAB Editor and press Ctrl+Enter to run one section at a time, or
%   Run to execute the whole script. To get a formatted document, use
%   publish('naive_bayes_three_examples.m'), or right-click the file and choose
%   "Save As" -> Live Script (.mlx) if you prefer the notebook-style interface.
%
% REQUIREMENTS
%   Base MATLAB R2018b or later. Local functions in a script need R2016b; xline and
%   yline, used in two plots, need R2018b. If you are on something older, replace those
%   two calls with plot() and the rest runs unchanged.
%   The Statistics and Machine Learning Toolbox is OPTIONAL - see the next section.
%
% A NOTE ON DESIGN
%   Unlike the Python and R versions, here the hand-rolled implementation is the
%   primary engine and the toolbox function fitcnb is the cross-check. Two reasons,
%   both explained in section 0: fitcnb lives in a separately licensed toolbox, and it
%   offers no Laplace smoothing parameter at all, which matters a great deal for the
%   14-row examples.

clear; clc; close all;
rng(42);                                    % reproducible splits and any sampling

fprintf('MATLAB %s\n', version);

%% 0. Setup, toolbox check, and MATLAB-specific traps
% fitcnb ships with the Statistics and Machine Learning Toolbox. Checking with `which`
% is more reliable than parsing `ver`, because it tells us whether the function is
% actually callable rather than merely whether a product is listed.

hasStats = ~isempty(which('fitcnb'));

if hasStats
    fprintf('Statistics and Machine Learning Toolbox: found (fitcnb available)\n');
else
    fprintf(['Statistics and Machine Learning Toolbox: NOT found.\n' ...
             'Every result below is still produced - the hand-rolled functions at the\n' ...
             'end of this file need only base MATLAB. The fitcnb cross-checks will be\n' ...
             'skipped.\n']);
end

%% First-run check
% Three numbers below are fixed by arithmetic, not by anything version- or
% platform-specific. If your run reproduces them, the script is working. If it does not,
% something in your setup differs and the rest of the output should not be trusted.
%
%   Section 1.3   P(Yes | Sunny)                          0.6000
%   Section 2.2   P(Yes | Senior, Contacted, High)        0.8527
%   Section 2.6   same case with alpha = 1                0.7523
%
% The two assertions on the AUC helper in section 3.5 serve the same purpose for
% Example 3: if either fails, the script stops there rather than producing plausible
% nonsense.

%% Which MATLAB function should you use?
% *fitcnb* (Statistics and ML Toolbox) is the only built-in Naive Bayes. It covers every
% variant through one name-value argument, |'DistributionNames'|:
%
%   'mvmn'    multivariate multinomial - the CATEGORICAL case. This is what matches the
%             lecture's worked examples.
%   'normal'  Gaussian, one mean and variance per class per predictor.
%   'kernel'  kernel density estimate, for continuous predictors that are clearly
%             not normal. No direct scikit-learn equivalent.
%   'mn'      multinomial, for count data such as word frequencies.
%
% You may also pass a cell array to mix distributions across predictors, e.g.
% |{'normal','mvmn','mvmn'}|. That is more convenient than either Python or R, where
% mixing requires either binning or combining two fitted models by hand.
%
% THREE MATLAB-SPECIFIC TRAPS
%
% 1. *fitcnb has no smoothing parameter.* scikit-learn has |alpha| (default 1) and R's
%    e1071 has |laplace| (default 0). MATLAB's |fitcnb| with |'mvmn'| has neither: it
%    uses raw relative frequencies, so an empty cell gives a likelihood of exactly zero
%    and there is no argument that changes this. If you need smoothing you must
%    implement it, which is why |nbByHand| below takes an |alpha|.
%
% 2. *Category order is not alphabetical unless you ask.* |categorical(c)| sorts levels,
%    but |categorical(c, valueset)| fixes them in the order you give. Every table and
%    every internal encoding inherits that order, so setting it explicitly is what keeps
%    output comparable with the slides.
%
% 3. *Table variable names must be valid MATLAB identifiers.* A class label like
%    |'<=50K'| cannot be a table variable name, so in Example 3 we carry the income
%    classes as |le50K| / |gt50K| and keep the display strings separately. Forgetting
%    this produces a confusing error deep inside |array2table|.
%
% One more, shared with R: |discretize| uses LEFT-CLOSED bins, [a,b), whereas R's |cut|
% is right-closed by default, (a,b]. Porting bin edges between the two languages without
% adjusting produces off-by-one-category bugs that are easy to miss.

%% Example 1 - Weather and Golf
% Slides 11-13. Fourteen days, one predictor, a binary outcome. The lecture asks: how
% likely are players to play if the weather is sunny? and answers 0.60.

weatherRaw = {'Sunny','Overcast','Rainy','Sunny','Sunny','Overcast','Rainy', ...
              'Rainy','Sunny','Rainy','Sunny','Overcast','Overcast','Rainy'};
playRaw    = {'No','Yes','Yes','Yes','Yes','Yes','No', ...
              'No','Yes','Yes','No','Yes','Yes','No'};

% Trap 2 in action: the second argument fixes the level order. Without it MATLAB would
% sort alphabetically, which here happens to coincide, but relying on that is fragile.
Weather = categorical(weatherRaw, {'Overcast','Rainy','Sunny'})';
Play    = categorical(playRaw,    {'No','Yes'})';

golf = table(Weather, Play);

fprintf('\n%d days\n', height(golf));
disp(head(golf, 5));

%% 1.1 The frequency table
% This is the counting step from slide 11. Nothing Bayesian has happened yet.
%
% We build it with a small helper rather than |crosstab| so the section works without
% the Statistics Toolbox, and so the row and column order is exactly the category order
% we set above.

[F, wLev, pLev] = freqTable(golf.Weather, golf.Play);

disp('Frequency table (rows = Weather, cols = Play):');
disp(withMargins(F, wLev, pLev));

% This is slide 11 exactly: Overcast 0/4, Rainy 3/2, Sunny 2/3, totals 5 No and 9 Yes.
% Note the ZERO in Overcast/No - no overcast day was ever a no-play day. That empty
% cell comes back in section 1.5.

%% 1.2 The likelihood table
% Divide by the COLUMN totals, because we want P(Weather | Play): the class is the
% given, so the class total is the denominator. Getting this margin backwards is the
% most common error in the whole exercise, so check it - each COLUMN must sum to 1.

L = F ./ sum(F, 1);                          % implicit expansion divides each column

disp('Likelihood table P(Weather | Play):');
disp(array2table(round(L, 3), 'RowNames', wLev, 'VariableNames', pLev(:)'));

fprintf('column sums (must be 1): %s\n', mat2str(round(sum(L, 1), 3)));
fprintf('row sums (meaningless - a row mixes two distributions): %s\n', ...
        mat2str(round(sum(L, 2)', 3)));

prior = sum(F, 1) / height(golf);
fprintf('\npriors: P(No)=%.3f  P(Yes)=%.3f\n', prior(1), prior(2));

%% 1.3 Bayes' theorem by hand
% With one predictor the denominator P(Sunny) is just a row total sitting in the
% frequency table, so we can apply slide 10 directly:
%
%   P(Yes | Sunny) = P(Sunny | Yes) * P(Yes) / P(Sunny)

iSunny = find(strcmp(wLev, 'Sunny'));
iYes   = find(strcmp(pLev, 'Yes'));
iNo    = find(strcmp(pLev, 'No'));

pSunnyGivenYes = L(iSunny, iYes);            % 3/9
pSunnyGivenNo  = L(iSunny, iNo);             % 2/5
pYes = prior(iYes);                          % 9/14
pNo  = prior(iNo);                           % 5/14
pSunny = sum(F(iSunny, :)) / height(golf);   % 5/14

postYes = pSunnyGivenYes * pYes / pSunny;
postNo  = pSunnyGivenNo  * pNo  / pSunny;

fprintf('P(Yes | Sunny) = %.4f\n', postYes);
fprintf('P(No  | Sunny) = %.4f\n', postNo);
fprintf('they sum to      %.4f\n', postYes + postNo);

% Sanity check straight from the raw data
isSunny = golf.Weather == 'Sunny';
fprintf('\ndirect count: %d of %d sunny days played = %.4f\n', ...
        sum(isSunny & golf.Play == 'Yes'), sum(isSunny), ...
        mean(golf.Play(isSunny) == 'Yes'));

%%
% 0.60, matching the slide, and the direct count confirms it: 3 of 5 sunny days were
% played. With a single predictor Bayes' theorem is *guaranteed* to recover the simple
% conditional proportion - it cannot do anything else. Good for checking your
% understanding, but it does not yet show what Naive Bayes is for. That is Example 2.

%% 1.4 The same thing with fitcnb
% No manual encoding is needed: MATLAB categorical arrays carry their own levels, so
% fitcnb takes the table as-is. (Contrast the Python version, which needs an
% OrdinalEncoder because scikit-learn only accepts numeric arrays.)

if hasStats
    % 'mvmn' = multivariate multinomial = the categorical case.
    % There is no smoothing argument to pass (trap 1), so this is the raw-count model,
    % which is exactly what the lecture's arithmetic uses.
    mdl1 = fitcnb(golf, 'Play', 'DistributionNames', 'mvmn');

    % newdata must use the SAME category set as the training data. Building it from
    % categories(golf.Weather) is the safe idiom.
    newday = table(categorical({'Sunny'}, categories(golf.Weather)), ...
                   'VariableNames', {'Weather'});

    [lab1, post1] = predict(mdl1, newday);

    fprintf('fitcnb classes:   %s\n', strjoin(string(mdl1.ClassNames), '  '));
    fprintf('fitcnb posterior: %s\n', mat2str(round(post1, 4)));
    fprintf('by hand:          No %.4f   Yes %.4f\n', postNo, postYes);
    fprintf('predicted class:  %s\n', string(lab1));
else
    fprintf('(skipped - no Statistics Toolbox)\n');
end

%% Opening up the fitted model
% The numbers stored inside the model should be the two tables we built by hand.

if hasStats
    fprintf('--- mdl1.Prior : the class priors ---\n');
    disp(array2table(round(mdl1.Prior(:)', 3), ...
         'VariableNames', cellstr(string(mdl1.ClassNames(:)))'));

    % DistributionParameters is a {class, predictor} cell array. For 'mvmn' each entry
    % is a column vector of probabilities over that predictor's levels, in the order
    % given by mdl1.CategoricalLevels{predictor}.
    % CategoricalLevels holds the level order fitcnb used. It should be populated for
    % an 'mvmn' predictor, but fall back to the categorical's own order if not, so a
    % display detail cannot crash the section.
    levs1 = mdl1.CategoricalLevels{1};
    if isempty(levs1)
        levs1 = categories(golf.Weather);
    end
    recovered = [mdl1.DistributionParameters{1, 1}, mdl1.DistributionParameters{2, 1}];

    fprintf('\n--- mdl1.DistributionParameters : the likelihoods ---\n');
    disp(array2table(round(recovered, 3), ...
         'RowNames', cellstr(string(levs1(:))), ...
         'VariableNames', cellstr(string(mdl1.ClassNames(:)))'));

    fprintf('--- what we built with freqTable + normalisation ---\n');
    disp(array2table(round(L, 3), 'RowNames', wLev, 'VariableNames', pLev(:)'));
end

%%
% The model *is* those tables. Training a Naive Bayes classifier is counting and
% dividing - no optimizer, no iteration. That is why it costs nothing as a baseline.
%
% Note the shape of |DistributionParameters|: it is indexed {class, predictor}, and each
% cell holds a vector over levels. That is a third convention, different from
% scikit-learn's |feature_log_prob_| (a list per feature, each classes-by-levels) and
% from R's |m$tables| (a list per feature, each classes-by-levels). None is wrong, but
% mixing them up silently transposes your likelihood table, so always print it and
% check that the columns sum to 1.

%% 1.5 The empty cell
% P(Overcast | No) = 0. Because fitcnb has no smoothing, the collapse is unavoidable
% and visible - which, for teaching purposes, is arguably an advantage over the other
% two libraries.

if hasStats
    overcast = table(categorical({'Overcast'}, categories(golf.Weather)), ...
                     'VariableNames', {'Weather'});
    [~, postOv] = predict(mdl1, overcast);
    fprintf('fitcnb, overcast: %s\n', mat2str(round(postOv, 4)));
    fprintf('-> 100%% certainty from one empty cell in 14 rows.\n');
end

% The fix is Laplace smoothing, which we have to supply ourselves. nbByHand takes alpha:
[pOv, labsOv] = nbByHand(golf(:, {'Weather'}), golf.Play, {'Overcast'}, 1, false);
fprintf('\nhand-rolled, alpha = 1, overcast:\n');
for c = 1:numel(labsOv)
    fprintf('  P(%s | Overcast) = %.4f\n', labsOv{c}, pOv(c));
end

[pSun, labsSun] = nbByHand(golf(:, {'Weather'}), golf.Play, {'Sunny'}, 1, false);
fprintf('hand-rolled, alpha = 1, sunny:\n');
for c = 1:numel(labsSun)
    fprintf('  P(%s | Sunny) = %.4f\n', labsSun{c}, pSun(c));
end

%%
% Compare the two libraries' defaults at this point:
%
%   scikit-learn CategoricalNB   alpha   = 1   smoothed by default
%   R e1071 naiveBayes           laplace = 0   unsmoothed by default
%   MATLAB fitcnb 'mvmn'         --            no smoothing, no option
%
% So MATLAB and R agree with the slides out of the box and Python does not; but only
% MATLAB gives you no way to change it. If you port an analysis between languages and
% the numbers move by a few percent, this is the first place to look.

%% Example 2 - Predicting Voter Turnout
% Fourteen respondents, three predictors, one binary outcome.
%
%   Age        Young / Middle / Senior                    predictor
%   Contacted  Yes / No - reached by a canvasser?          predictor
%   Interest   High / Low - interest in politics           predictor
%   Vote       Yes / No                                    class to predict
%
% Three predictors is what makes this worth doing. The joint
% P(Age, Contacted, Interest | c) cannot be estimated from 14 rows - almost every
% three-way combination appears zero or one time - so we need the independence
% assumption that gives the method its name.

ageRaw  = {'Young','Young','Middle','Senior','Senior','Senior','Middle', ...
           'Young','Young','Senior','Young','Middle','Middle','Senior'};
contRaw = {'No','No','No','No','Yes','Yes','Yes', ...
           'No','Yes','No','Yes','Yes','No','No'};
intRaw  = {'Low','High','High','Low','High','High','High', ...
           'Low','Low','High','Low','Low','High','Low'};
voteRaw = {'No','No','Yes','Yes','Yes','No','Yes', ...
           'No','Yes','Yes','Yes','Yes','Yes','No'};

Age       = categorical(ageRaw,  {'Young','Middle','Senior'})';
Contacted = categorical(contRaw, {'No','Yes'})';
Interest  = categorical(intRaw,  {'Low','High'})';
Vote      = categorical(voteRaw, {'No','Yes'})';

voters = table(Age, Contacted, Interest, Vote);
FEATURES = {'Age','Contacted','Interest'};

fprintf('\n');
disp(countcatsTable(voters.Vote));
disp(voters);

%% 2.1 One frequency table per predictor
% This is the structural consequence of the independence assumption: three small
% marginal tables instead of one 12-cell joint table that 14 observations could never
% fill.

for k = 1:numel(FEATURES)
    [Fk, rl, cl] = freqTable(voters.(FEATURES{k}), voters.Vote);
    fprintf('--- %s ---\n', FEATURES{k});
    disp(withMargins(Fk, rl, cl));
end

%%
% Every table has the same column totals (5 No, 9 Yes) and sums to 14. If yours does
% not, you miscounted.
%
% Middle/No is ZERO - no middle-aged respondent failed to vote. Section 2.5.

%% 2.2 Naive Bayes written out longhand
% Before reaching for the toolbox, the whole algorithm is in |nbByHand| at the bottom of
% this file - about twenty lines. Nothing is hidden, so it is the ground truth against
% which everything else is checked.

newCase = {'Senior','Yes','High'};

fprintf('Scoring Age=Senior, Contacted=Yes, Interest=High\n');
[post2, labs2] = nbByHand(voters(:, FEATURES), voters.Vote, newCase, 0, true);

fprintf('\nposteriors:\n');
for c = 1:numel(labs2)
    fprintf('  P(%s | x) = %.4f\n', labs2{c}, post2(c));
end

%%
% About 0.853 for Yes and 0.147 for No - the numbers from the slides. This person is
% predicted to vote, with roughly 85% confidence.

%% 2.3 The same thing with fitcnb

if hasStats
    mdl2 = fitcnb(voters, 'Vote', 'DistributionNames', 'mvmn');

    q2 = makeRow(newCase, voters, FEATURES);
    disp(q2);

    [lab2, p2] = predict(mdl2, q2);
    fprintf('fitcnb classes:   %s\n', strjoin(string(mdl2.ClassNames), '  '));
    fprintf('fitcnb posterior: %s\n', mat2str(round(p2, 4)));
    fprintf('by hand:          %s\n', mat2str(round(post2', 4)));
    fprintf('predicted class:  %s\n', string(lab2));
end

%% 2.4 Which predictor drove the prediction?
% Naive Bayes decomposes into one factor per predictor, so you can always say which
% feature did the work. The ratio of the two likelihoods tells you which way a term
% pushes: above 1 favours Yes, below 1 favours No.

C = contributionTable(voters(:, FEATURES), voters.Vote, newCase, 0);
disp(C);
fprintf('product of the ratios = %.3f  <- the odds in favour of Yes\n', ...
        prod(C.ratio_Yes_No));

%%
% Read the ratio column: being contacted is the strongest signal (roughly 2.8 to 1
% toward voting), high interest helps mildly, and being Senior leans SLIGHTLY AGAINST
% voting (ratio below 1) but is outweighed. Multiply the ratios and you get the final
% odds - the same computation rearranged.

%% 2.5 The zero-frequency problem
% Now classify someone Middle aged, not contacted, Low interest.
% P(Middle | No) = 0, and one zero annihilates the whole product.

hardCase = {'Middle','No','Low'};

fprintf('Age=Middle, Contacted=No, Interest=Low  (alpha = 0)\n');
[postHard, labsHard] = nbByHand(voters(:, FEATURES), voters.Vote, hardCase, 0, true);
fprintf('\nposteriors:\n');
for c = 1:numel(labsHard)
    fprintf('  P(%s | x) = %.4f\n', labsHard{c}, postHard(c));
end
fprintf(['\nThe other two predictors both lean No, and the zero wiped them out\n' ...
         'before they could contribute.\n']);

if hasStats
    qh = makeRow(hardCase, voters, FEATURES);
    [~, ph] = predict(mdl2, qh);
    fprintf('\nfitcnb agrees (and has no way to avoid it): %s\n', mat2str(round(ph, 4)));
end

%% 2.6 Laplace smoothing, the actual fix
%
%   P(x_i | c) = (count + alpha) / (n_c + alpha * k)
%
% where k is the number of categories that predictor has. Because fitcnb cannot do
% this, |nbByHand| is not a teaching toy here - it is the only route to a smoothed
% model without writing your own classifier or reaching for a third-party toolbox.

fprintf('alpha = 1:\n');
[postSm, labsSm] = nbByHand(voters(:, FEATURES), voters.Vote, hardCase, 1, true);
fprintf('\nposteriors:\n');
for c = 1:numel(labsSm)
    fprintf('  P(%s | x) = %.4f\n', labsSm{c}, postSm(c));
end
fprintf('-> 0.248 / 0.752, matching the smoothed arithmetic from the slides\n');

% What smoothing did to the Age likelihoods for Vote = No
levsAge = categories(voters.Age);
maskNo  = voters.Vote == 'No';
nNo     = sum(maskNo);
before  = zeros(numel(levsAge), 1);
after   = zeros(numel(levsAge), 1);
for i = 1:numel(levsAge)
    cnt = sum(maskNo & voters.Age == levsAge{i});
    before(i) = cnt / nNo;
    after(i)  = (cnt + 1) / (nNo + 1 * numel(levsAge));
end

fprintf('\nP(Age | Vote = No):\n');
disp(array2table(round([before after], 3), 'RowNames', levsAge, ...
     'VariableNames', {'alpha_0','alpha_1'}));
fprintf(['Note: the empty Middle cell moves 0.000 -> 0.125, while the well-supported\n' ...
         'cells barely move. That asymmetry is exactly what you want.\n']);

%% How much does alpha matter?

alphas = [0 0.01 0.1 0.5 1 2 5 20];
sweep = zeros(numel(alphas), 2);
for i = 1:numel(alphas)
    pA = nbByHand(voters(:, FEATURES), voters.Vote, newCase,  alphas(i), false);
    pB = nbByHand(voters(:, FEATURES), voters.Vote, hardCase, alphas(i), false);
    sweep(i, 1) = pA(2);        % index 2 = 'Yes', matching categories(voters.Vote)
    sweep(i, 2) = pB(2);
end

disp(array2table(round([alphas' sweep], 4), 'VariableNames', ...
     {'alpha','P_Yes_SeniorYesHigh','P_Yes_MiddleNoLow'}));

%%
% A log x-axis cannot show alpha = 0, so we plot the positive values; the alpha = 0
% endpoint is in the table above.

pos = alphas > 0;
figure('Position', [100 100 700 420]);
semilogx(alphas(pos), sweep(pos, 2), '-o', 'LineWidth', 1.6, ...
         'Color', [0.69 0.19 0.19], 'MarkerFaceColor', [0.69 0.19 0.19]); hold on;
semilogx(alphas(pos), sweep(pos, 1), '-^', 'LineWidth', 1.6, ...
         'Color', [0.13 0.38 0.48], 'MarkerFaceColor', [0.13 0.38 0.48]);
yline(mean(voters.Vote == 'Yes'), '--', 'base rate 9/14', 'Color', [0.4 0.4 0.4]);
ylim([0.5 1.05]);
xlabel('\alpha (log scale; \alpha = 0 omitted)');
ylabel('P(Vote = Yes | x)');
title('Smoothing drags both predictions toward the base rate');
legend({'Middle / No / Low (had the zero)','Senior / Yes / High'}, ...
       'Location', 'southwest'); legend boxoff; grid on; hold off;

%%
% As alpha grows every estimate is dragged toward uniform and both predictions decay
% toward the base rate, 0.6429. With 14 rows, alpha = 20 has essentially erased the
% data. The effect shrinks as n grows, which is why the same value is decisive here and
% harmless on the 32,000-row dataset in Example 3.

%% 2.7 An honest caveat
% Rows 5 and 6 have identical predictors and opposite outcomes.

dupMask = voters.Age == 'Senior' & voters.Contacted == 'Yes' & voters.Interest == 'High';
disp(voters(dupMask, :));
fprintf('Actual outcome for this exact profile: %d of %d voted. Model said 0.85.\n', ...
        sum(voters.Vote(dupMask) == 'Yes'), sum(dupMask));

%%
% So the truthful answer for that profile is 50/50, and our 85% is overconfident. That
% gap is the independence assumption showing its cost: multiplying three separately
% favourable likelihoods treats them as three independent witnesses when they overlap
% (canvassers plausibly target older or more engaged voters). Evidence gets
% double-counted and the posterior is pushed too far from 0.5.
%
% This is the standard, well-documented weakness: Naive Bayes RANKINGS and hard
% decisions are often fine, its PROBABILITIES are not. We measure that in Example 3.

%% Example 3 - Income, Education and Inequality (1994 US Census)
% THE DATASET
%
% The UCI "Adult" / Census Income data is an extract from the 1994 US Census Current
% Population Survey, assembled by Barry Becker and Ronny Kohavi. UCI files it under
% Social Science, and it has been central to both machine learning and
% algorithmic-fairness research for thirty years.
%
%   Source:   https://archive.ics.uci.edu/dataset/2/adult
%   Citation: Becker, B. & Kohavi, R. (1996). Adult. UCI Machine Learning Repository.
%             https://doi.org/10.24432/C5XW20  (CC BY 4.0)
%
% TASK: predict whether annual income exceeds $50,000 from education, occupation,
% marital status, hours worked, sex, race, age and so on.
%
% We load adult.data, the 32,561-row training portion. A further 16,281 rows live in
% adult.test, which uses a slightly different label format (a trailing period).
%
% WHY THIS IS A SOCIOLOGY PROBLEM
%
% The features are exactly the variables stratification research cares about. Fitting a
% classifier here asks: how legible is the income distribution from demographic
% characteristics alone? And, more interestingly, which characteristics carry the most
% information, and for whom does the model fail?
%
% Three things to keep in view:
%
% 1. The $50,000 threshold is arbitrary and dated. In 1994 dollars it sat near the 80th
%    percentile of individual earnings. Dichotomising a continuous outcome discards
%    information, and where you cut determines what "high income" means.
% 2. Prediction is not explanation. A large weight on marital status does not mean
%    marriage causes income.
% 3. The independence assumption will be badly violated, in ways we can measure
%    (section 3.8).

%% 3.1 Loading the data
% Needs an internet connection the first time; after that it reads the cached file.

COLUMNS = {'age','workclass','fnlwgt','education','education_num', ...
           'marital_status','occupation','relationship','race','sex', ...
           'capital_gain','capital_loss','hours_per_week', ...
           'native_country','income'};

UCI_URL = ['https://archive.ics.uci.edu/ml/machine-learning-databases/' ...
           'adult/adult.data'];
LOCAL = 'adult.data';

if ~isfile(LOCAL)
    fprintf('downloading from the UCI archive ...\n');
    websave(LOCAL, UCI_URL);
    fprintf('saved to %s\n', LOCAL);
else
    fprintf('using cached %s\n', LOCAL);
end

% The file has no header row and pads fields with leading spaces. We read everything as
% text-or-number with explicit variable names, then clean each column ourselves - more
% verbose than relying on import options, but it behaves the same across MATLAB
% releases, whose readtable defaults have changed several times.
adult = readtable(LOCAL, 'FileType', 'text', 'Delimiter', ',', ...
                  'ReadVariableNames', false);
adult.Properties.VariableNames = COLUMNS;

fprintf('%s rows x %d columns\n', ...
        addThousandsSep(height(adult)), width(adult));
disp(head(adult, 5));

%% 3.2 What are we looking at?
% Always do this first: how imbalanced is the outcome, where are the missing values,
% does anything look wrong?

% Normalise the income column to a clean categorical. Trap 3: '<=50K' and '>50K' cannot
% be table variable names, so we use le50K / gt50K and keep the display strings apart.
incomeStr = strtrim(string(adult.income));
incomeStr = erase(incomeStr, ".");                   % adult.test adds a trailing period
y = categorical(incomeStr == ">50K", [false true], {'le50K','gt50K'});
INCOME_DISPLAY = {'<=50K','>50K'};

fprintf('--- outcome ---\n');
disp(countcatsTable(y));
baseRate = mean(y == 'gt50K');
fprintf('base rate: %.4f earn >50K\n', baseRate);
fprintf(['-> always guessing <=50K is %.1f%% accurate and has learned nothing.\n' ...
         '   Accuracy will be a poor summary of this model.\n'], 100 * (1 - baseRate));

% Missing values: UCI codes them as a literal '?'. Count them before we recode.
fprintf('\n--- missing (coded as ?) ---\n');
for k = 1:width(adult)
    v = adult.Properties.VariableNames{k};
    col = adult.(v);
    if iscell(col) || isstring(col)
        nq = sum(strtrim(string(col)) == "?");
        if nq > 0
            fprintf('  %-16s %5d rows (%.2f%%)\n', v, nq, 100 * nq / height(adult));
        end
    end
end

fprintf('\n--- numeric summary ---\n');
numVars = {'age','hours_per_week','capital_gain','capital_loss', ...
           'education_num','fnlwgt'};
S = zeros(numel(numVars), 5);
for k = 1:numel(numVars)
    x = adult.(numVars{k});
    S(k, :) = [min(x) prctile2(x, 25) median(x) prctile2(x, 75) max(x)];
end
disp(array2table(round(S, 1), 'RowNames', numVars, ...
     'VariableNames', {'min','p25','median','p75','max'}));

%%
% Two columns need a decision, and both decisions are substantive rather than
% technical:
%
% * *fnlwgt* is the census SAMPLING WEIGHT - how many people in the population each row
%   represents. It is not a property of the person and must not be a predictor. (It
%   arguably should be used to weight the analysis, which is a real limitation of how
%   this dataset is almost always modelled, including here.)
% * *education_num* is a numeric recoding of *education*. Including both feeds the same
%   information in twice, and because Naive Bayes multiplies likelihoods, duplicated
%   evidence gets counted twice over. We keep the readable categorical version.

%% 3.3 Feature engineering
% We put everything through the categorical path, which means binning the continuous
% variables. A real trade-off:
%
% * COST: binning discards within-bin variation and the cut points are our invention.
% * BENEFIT: it drops the normality assumption that 'normal' would impose. For age that
%   assumption is defensible; for capital_gain it is not - the variable is zero for
%   about 92% of people and enormous for a few. No normal distribution fits that, and
%   fitting one anyway would corrupt every prediction involving it.
%
% So capital_gain and capital_loss become yes/no indicators, which is closer to what
% they measure: whether someone holds income-generating assets.
%
% Remember that |discretize| uses LEFT-CLOSED bins [a,b). The edges below are therefore
% NOT the same numbers as the R version's, even though the bands are identical.

d = table();

d.age_band = discretize(adult.age, [16 25 35 45 55 65 Inf], 'categorical', ...
                        {'17-24','25-34','35-44','45-54','55-64','65+'});

d.hours_band = discretize(adult.hours_per_week, [0 35 45 60 Inf], 'categorical', ...
                          {'part-time (<35)','full-time (35-44)', ...
                           'long (45-59)','very long (60+)'});

d.capital_gain_yn = categorical(adult.capital_gain > 0, [false true], {'no','yes'});
d.capital_loss_yn = categorical(adult.capital_loss > 0, [false true], {'no','yes'});

% The genuinely categorical columns. Missing values become their own level: for a
% categorical Naive Bayes this is cheap and often better than imputation, because if
% non-response is itself informative - and in labour-force surveys it usually is - the
% model can learn from it. Dropping the rows throws that away and biases the sample.
textVars = {'workclass','education','marital_status','occupation', ...
            'relationship','race','sex','native_country'};
for k = 1:numel(textVars)
    v = textVars{k};
    s = strtrim(string(adult.(v)));
    s(ismissing(s) | s == "" | s == "?") = "Missing";
    d.(v) = categorical(s);
end

CAT = [{'age_band','hours_band','capital_gain_yn','capital_loss_yn'}, textVars];

fprintf('share with any capital gain: %.4f\n', mean(adult.capital_gain > 0));
fprintf('share with any capital loss: %.4f\n', mean(adult.capital_loss > 0));
fprintf('\nage bands:\n');   disp(countcatsTable(d.age_band));
fprintf('hours bands:\n');   disp(countcatsTable(d.hours_band));

% No NaNs may survive into the model. discretize returns <undefined> for out-of-range
% values, so assert rather than assume.
for k = 1:numel(CAT)
    assert(~any(isundefined(d.(CAT{k}))), ...
           'undefined categories in %s - check your bin edges', CAT{k});
end
fprintf('\nall %d predictors are fully defined categoricals\n', numel(CAT));

%% Collapsing ultra-rare levels
% Not cosmetic. native_country has 42 levels, several with a handful of observations
% (Holand-Netherlands has exactly ONE row in the whole dataset). Two problems follow:
%
% * STATISTICALLY, a likelihood estimated from one observation is noise. And since
%   fitcnb does no smoothing, a level absent from one class contributes an exact zero.
% * MECHANICALLY, a level that lands entirely in the test split makes the logistic
%   regression comparison in 3.6 fail outright. Naive Bayes tolerates this; fitglm
%   does not.
%
% So we merge levels below a minimum count into 'Other' before splitting. This is
% outcome-independent - we are counting rows, not looking at income - so doing it on
% the full dataset is safe.

before_n = zeros(numel(CAT), 1);
after_n  = zeros(numel(CAT), 1);
for k = 1:numel(CAT)
    before_n(k) = numel(categories(d.(CAT{k})));
    d.(CAT{k})  = lumpRare(d.(CAT{k}), 20);
    after_n(k)  = numel(categories(d.(CAT{k})));
end

chg = before_n ~= after_n;
if any(chg)
    fprintf('features whose level count shrank:\n');
    disp(array2table([before_n(chg) after_n(chg)], 'RowNames', CAT(chg), ...
         'VariableNames', {'before','after'}));
else
    fprintf('no levels were rare enough to merge\n');
end

smallest = inf;
for k = 1:numel(CAT)
    smallest = min(smallest, min(countcats(d.(CAT{k}))));
end
fprintf('smallest level count remaining: %d\n', smallest);

%% 3.4 Train/test split, stratified
% A plain randperm split can hand you a test set with a noticeably different base rate,
% which makes the metrics hard to interpret. We stratify by splitting within each class.
% (cvpartition would do this too, but it needs the Statistics Toolbox and we want this
% section to work without it.)

testFrac = 0.25;
classes = categories(y);
testIdx = [];
for c = 1:numel(classes)
    idx = find(y == classes{c});
    idx = idx(randperm(numel(idx)));
    nTest = round(testFrac * numel(idx));
    testIdx = [testIdx; idx(1:nTest)];                                  %#ok<AGROW>
end
testIdx  = sort(testIdx);
trainIdx = setdiff((1:height(d))', testIdx);

Xtrain = d(trainIdx, CAT);   ytrain = y(trainIdx);
Xtest  = d(testIdx,  CAT);   ytest  = y(testIdx);

fprintf('train %s   test %s\n', addThousandsSep(numel(trainIdx)), ...
        addThousandsSep(numel(testIdx)));
fprintf('base rate  train %.4f   test %.4f\n', ...
        mean(ytrain == 'gt50K'), mean(ytest == 'gt50K'));

%% 3.5 Metric helpers, and their self-tests
% No toolbox needed. AUC comes from the rank-based Mann-Whitney identity, which is
% exact and handles ties by average ranks:
%
%   AUC = (sum of positive ranks - n_pos(n_pos+1)/2) / (n_pos * n_neg)
%
% Note that |tiedrank| is itself a Statistics Toolbox function, so |aucScore| below
% computes average ranks by hand.

assert(abs(aucScore([0;0;1;1], [0.1;0.2;0.3;0.4]) - 1) < 1e-12, 'AUC self-test 1 failed');
assert(abs(aucScore([0;1], [0.5;0.5]) - 0.5) < 1e-12, 'AUC self-test 2 failed');
fprintf('AUC helper self-tested OK (a perfect ranking scores 1, a tie scores 0.5)\n');

%% 3.6 Fit, and compare against honest baselines
% A model's accuracy means nothing alone. Two reference points:
%
% * MAJORITY-CLASS BASELINE - the floor. About 76% accurate here, having learned nothing.
% * LOGISTIC REGRESSION - comparable simplicity, but does NOT assume feature
%   independence. If Naive Bayes lands far below it, the independence assumption is
%   costing us; if close, it is doing little harm.

% --- hand-rolled Naive Bayes, alpha = 1 (works with no toolbox) ---
nbModel = nbFit(Xtrain, ytrain, 1);
[predHand, postHand] = nbPredict(nbModel, Xtest);
scoreHand = postHand(:, 2);                  % column 2 = 'gt50K'

yTestNum = double(ytest == 'gt50K');
repHand = classificationReport(ytest, predHand, 'gt50K');

% --- majority baseline ---
majority = repmat(categorical({'le50K'}, classes), numel(ytest), 1);
repMaj = classificationReport(ytest, majority, 'gt50K');

rows = {'majority baseline'; 'naive Bayes by hand (alpha=1)'};
acc  = [repMaj.accuracy;          repHand.accuracy];
bal  = [repMaj.balancedAccuracy;  repHand.balancedAccuracy];
auc  = [NaN;                      aucScore(yTestNum, scoreHand)];

% --- fitcnb, for comparison (no smoothing) ---
if hasStats
    tTrain = Xtrain; tTrain.income = ytrain;
    mdl3 = fitcnb(tTrain, 'income', 'DistributionNames', 'mvmn');
    [predNb, postNb] = predict(mdl3, Xtest);
    scoreNb = postNb(:, find(mdl3.ClassNames == 'gt50K'));   %#ok<FNDSB>
    repNb = classificationReport(ytest, predNb, 'gt50K');

    rows{end+1, 1} = 'fitcnb mvmn (no smoothing)';
    acc(end+1)  = repNb.accuracy;
    bal(end+1)  = repNb.balancedAccuracy;
    auc(end+1)  = aucScore(yTestNum, scoreNb);

    % --- logistic regression ---
    % Guard against the failure mode described in 3.3 before fitting.
    unseen = {};
    for k = 1:numel(CAT)
        a = categories(removecats(Xtest.(CAT{k})));
        b = categories(removecats(Xtrain.(CAT{k})));
        miss = setdiff(a, b);
        if ~isempty(miss)
            unseen{end+1} = sprintf('%s: %s', CAT{k}, strjoin(miss', ', ')); %#ok<AGROW>
        end
    end
    if isempty(unseen)
        fprintf('level check passed: every test level appears in train\n');
    else
        fprintf('WARNING - levels in test but not train:\n');
        fprintf('  %s\n', unseen{:});
    end

    glmTrain = Xtrain; glmTrain.income = double(ytrain == 'gt50K');
    % The predictor columns are already categorical, so fitglm detects them
    % automatically -- no CategoricalVars argument needed.
    lrModel = fitglm(glmTrain, 'linear', 'ResponseVar', 'income', ...
                     'Distribution', 'binomial');
    scoreLr = predict(lrModel, Xtest);
    predLr  = categorical(scoreLr > 0.5, [false true], classes);
    repLr   = classificationReport(ytest, predLr, 'gt50K');

    rows{end+1, 1} = 'logistic regression';
    acc(end+1)  = repLr.accuracy;
    bal(end+1)  = repLr.balancedAccuracy;
    auc(end+1)  = aucScore(yTestNum, scoreLr);
end

% NOTE: round() does not accept a table, so round the columns before assembling.
results = table(round(acc, 4), round(bal, 4), round(auc, 4), 'RowNames', rows, ...
                'VariableNames', {'accuracy','balanced_acc','AUC'});
disp(results);

%%
% READING THAT TABLE. Look at balanced_acc and AUC, not accuracy. The majority baseline
% posts a high accuracy and a balanced accuracy of exactly 0.50 - it is right about
% everyone who earns less and wrong about everyone who earns more. Balanced accuracy
% averages the per-class recall, so it exposes that at once. AUC asks a different and
% often more useful question: draw one high earner and one low earner at random; how
% often does the model score the high earner higher?
%
% Compare the two Naive Bayes rows. With 24,000 training rows every cell is well
% populated, so the presence or absence of smoothing should barely matter - the opposite
% of what we saw with 14 rows in section 2.6.

fprintf('--- confusion matrix, hand-rolled Naive Bayes ---\n');
disp(array2table(repHand.confusion, ...
     'RowNames', strcat('actual_', INCOME_DISPLAY), ...
     'VariableNames', strcat('pred_', {'le50K','gt50K'})));
fprintf('accuracy          %.4f\n', repHand.accuracy);
fprintf('balanced accuracy %.4f\n', repHand.balancedAccuracy);
fprintf('precision (>50K)  %.4f\n', repHand.precision);
fprintf('recall    (>50K)  %.4f\n', repHand.recall);
fprintf('F1        (>50K)  %.4f\n', repHand.f1);

%%
% Mind the gap between precision and recall on >50K. Which matters depends entirely on
% the application, and that is a substantive question. If this model screened people for
% a benefits programme, a false negative (missing someone who needs help) and a false
% positive (enrolling someone who does not) carry very different human costs, and no
% single number captures the trade-off.

%% ROC curves

figure('Position', [100 100 640 560]);
[fpr1, tpr1] = rocPoints(yTestNum, scoreHand);
plot(fpr1, tpr1, 'LineWidth', 2, 'Color', [0.13 0.38 0.48]); hold on;
legEntries = {sprintf('naive Bayes by hand (AUC %.3f)', aucScore(yTestNum, scoreHand))};

if hasStats
    [fpr2, tpr2] = rocPoints(yTestNum, scoreLr);
    plot(fpr2, tpr2, 'LineWidth', 2, 'Color', [0.69 0.19 0.19]);
    legEntries{end+1} = sprintf('logistic regression (AUC %.3f)', ...
                                aucScore(yTestNum, scoreLr));
end

plot([0 1], [0 1], '--', 'Color', [0.5 0.5 0.5]);
legEntries{end+1} = 'chance';
xlabel('false positive rate'); ylabel('true positive rate');
title('Predicting income > $50K, 1994 US Census');
legend(legEntries, 'Location', 'southeast'); legend boxoff;
axis square; grid on; hold off;

%% 3.7 Interpretation: which characteristics carry information?
% The part a sociologist actually wants. For each category compute the EVIDENCE WEIGHT
%
%   w = log[ P(category | >$50K) / P(category | <=$50K) ]
%
% Positive means the category is more common among high earners, so observing it shifts
% the prediction upward. This reads straight off the fitted likelihood tables - no extra
% fitting, because the trained model already IS these tables.
%
% Two warnings before reading the output. These are ASSOCIATIONS IN 1994 SURVEY DATA,
% not causal effects and not current facts. And a weight can be large while the category
% is rare, so always read the probabilities beside the ratio.

showFeatures = {'education','marital_status','occupation'};

for k = 1:numel(showFeatures)
    E = evidenceWeights(nbModel, showFeatures{k}, 0.01);
    fprintf('\n=== %s %s\n', showFeatures{k}, repmat('=', 1, max(0, 44 - numel(showFeatures{k}))));
    disp(E);
end

%%

figure('Position', [100 100 780 980]);
for k = 1:numel(showFeatures)
    E = evidenceWeights(nbModel, showFeatures{k}, 0.01);
    E = sortrows(E, 'evidence_weight', 'ascend');

    subplot(3, 1, k);
    w = E.evidence_weight;
    b = barh(w, 'FaceColor', 'flat');
    for i = 1:numel(w)
        if w(i) < 0, b.CData(i, :) = [0.69 0.19 0.19];
        else,        b.CData(i, :) = [0.13 0.38 0.48];
        end
    end
    yticks(1:numel(w));
    yticklabels(E.Properties.RowNames);
    set(gca, 'FontSize', 8);
    xline(0, 'k-');
    xlabel('log P(cat | >50K) / P(cat | <=50K)');
    title(strrep(showFeatures{k}, '_', ' '), 'FontSize', 11);
end

%%
% WHAT TO LOOK FOR, AND HOW TO BE CAREFUL
%
% Read the education panel first. The ordering should be close to monotone in credential
% level, which is the most robust finding in stratification research and a good sign the
% model is picking up something real rather than noise.
%
% Then read marital_status, carefully. Married-civ-spouse will almost certainly carry a
% large positive weight, and it is tempting to narrate that as "marriage raises income."
% At least four mechanisms are tangled in that one number, and this model separates none
% of them:
%
% 1. SELECTION - higher earners are more likely to marry in the first place.
% 2. MEASUREMENT - the income variable interacts with household and filing structure.
% 3. AGE CONFOUNDING - married people are older, and earnings rise with age.
% 4. GENDERED SPECIALISATION within households.
%
% A Naive Bayes weight is a MARGINAL association: it compares married to unmarried
% people without holding age, education or occupation constant. This is precisely where
% a classifier stops being able to answer the question you want answered and you need a
% research design instead.

%% 3.8 Auditing the independence assumption
% We assumed the predictors are conditionally independent given income. Let us measure
% how false that is with Cramer's V, a chi-squared-based association measure for two
% categorical variables scaled to [0, 1]. Computed from the contingency table directly,
% so no toolbox is needed.

p = numel(CAT);
V = eye(p);
for i = 1:p
    for j = i+1:p
        v = cramersV(d.(CAT{i}), d.(CAT{j}));
        V(i, j) = v;
        V(j, i) = v;
    end
end

% strongest pairs, upper triangle only
[ii, jj] = find(triu(ones(p), 1));
vals = arrayfun(@(a, b) V(a, b), ii, jj);
[~, ord] = sort(vals, 'descend');
nShow = min(10, numel(ord));
fprintf('most strongly associated predictor pairs:\n');
for k = 1:nShow
    m = ord(k);
    fprintf('  V(%s, %s) = %.3f\n', CAT{ii(m)}, CAT{jj(m)}, vals(m));
end

%%

figure('Position', [100 100 760 660]);
imagesc(V, [0 1]);
colormap(flipud(hot)); colorbar;
xticks(1:p); xticklabels(strrep(CAT, '_', ' ')); xtickangle(45);
yticks(1:p); yticklabels(strrep(CAT, '_', ' '));
set(gca, 'FontSize', 8);
title({'Cramer''s V between predictors', ...
       '(Naive Bayes assumes every off-diagonal cell is 0)'}, 'FontSize', 11);
axis square;

%%
% Naive Bayes assumes every off-diagonal cell there is zero. It is not. The
% marital_status / relationship / sex cluster should stand out sharply - relationship
% takes values like Husband and Wife, which encode marital status and sex BY
% CONSTRUCTION, so the model counts the same fact up to three times.
%
% Yet the AUC above was respectable. That is the enduring puzzle about Naive Bayes, and
% the resolution is worth stating precisely: violated independence corrupts the
% PROBABILITIES far more than the RANKING. Double-counted evidence pushes posteriors
% toward 0 and 1, but it usually pushes them in the direction they were already going,
% so the ordering of cases - and hence AUC, and hence the argmax decision - survives.

%% Does dropping the redundancy help?

CAT_TRIM = setdiff(CAT, {'relationship'}, 'stable');
nbTrim = nbFit(Xtrain(:, CAT_TRIM), ytrain, 1);
[~, postTrim] = nbPredict(nbTrim, Xtest(:, CAT_TRIM));

fprintf('with relationship:    AUC %.4f\n', aucScore(yTestNum, scoreHand));
fprintf('without relationship: AUC %.4f\n', aucScore(yTestNum, postTrim(:, 2)));
fprintf(['\nIf dropping a redundant feature barely moves AUC while that feature had a\n' ...
         'high Cramer''s V with others, you are seeing the effect described above: the\n' ...
         'ranking was robust to the violation even though the probabilities were not.\n']);

%% 3.9 Calibration: are the probabilities trustworthy?
% In Example 2 we predicted 0.85 for a profile whose true rate was 0.50. Let us measure
% that failure mode properly. Group the test set by predicted probability and compare
% the average prediction in each bucket to the actual rate. A calibrated model puts
% those close together.

calNb = calibrationTable(scoreHand, yTestNum, 10);
disp(calNb);

%%

figure('Position', [100 100 1100 470]);

subplot(1, 2, 1);
plot(calNb.mean_predicted, calNb.actual_rate, '-o', 'LineWidth', 2, ...
     'Color', [0.13 0.38 0.48], 'MarkerFaceColor', [0.13 0.38 0.48]); hold on;
legC = {'naive Bayes'};
if hasStats
    calLr = calibrationTable(scoreLr, yTestNum, 10);
    plot(calLr.mean_predicted, calLr.actual_rate, '-^', 'LineWidth', 2, ...
         'Color', [0.69 0.19 0.19], 'MarkerFaceColor', [0.69 0.19 0.19]);
    legC{end+1} = 'logistic regression';
end
plot([0 1], [0 1], '--', 'Color', [0.4 0.4 0.4]);
legC{end+1} = 'perfect calibration';
xlabel('mean predicted probability'); ylabel('observed rate of >$50K');
title('Reliability curve'); xlim([0 1]); ylim([0 1]);
legend(legC, 'Location', 'northwest'); legend boxoff; grid on; hold off;

subplot(1, 2, 2);
histogram(scoreHand, 40, 'FaceColor', [0.13 0.38 0.48], 'FaceAlpha', 0.6, ...
          'EdgeColor', 'none'); hold on;
legH = {'naive Bayes'};
if hasStats
    histogram(scoreLr, 40, 'FaceColor', [0.69 0.19 0.19], 'FaceAlpha', 0.5, ...
              'EdgeColor', 'none');
    legH{end+1} = 'logistic regression';
end
xlabel('predicted P(income > $50K)'); ylabel('count');
title('Where the predicted probabilities pile up');
legend(legH, 'Location', 'north'); legend boxoff; hold off;

%%
% Look at the right-hand histogram. Naive Bayes tends to pile predictions against 0 and
% 1 while logistic regression spreads them through the middle. That is the
% double-counting of correlated evidence, visible directly.
%
% The Brier score measures calibration and accuracy together - lower is better:

fprintf('naive Bayes:         %.4f\n', mean((scoreHand - yTestNum).^2));
if hasStats
    fprintf('logistic regression: %.4f\n', mean((scoreLr - yTestNum).^2));
end

%%
% THE PRACTICAL RULE: use Naive Bayes probabilities to RANK cases, not as calibrated
% risk estimates. If you need the number itself to mean something - "this person has a
% 30% chance" - recalibrate on a held-out split (Platt scaling: fit a logistic
% regression of the outcome on the model's log-odds; or isotonic regression, which you
% would have to implement, as MATLAB exposes no supported function for it) or use a
% method that estimates probabilities properly.

%% 3.10 Who does the model fail?
% An aggregate metric hides distributional damage. A model can look fine overall and be
% systematically worse for a subgroup. The features here include sex and race, so we can
% and should check.
%
% This is a descriptive audit, not a fairness verdict - "fairness" has several mutually
% incompatible formal definitions, and choosing among them is an ethical and political
% question a script does not settle.

fprintf('=== by sex %s\n', repmat('=', 1, 50));
disp(subgroupReport(d.sex(testIdx), ytest, predHand, 'gt50K'));

fprintf('=== by race %s\n', repmat('=', 1, 49));
disp(subgroupReport(d.race(testIdx), ytest, predHand, 'gt50K'));

%%
% Compare the RECALL column across groups. Recall is the share of genuinely
% high-earning people the model finds. If it is markedly lower for one group, the model
% disproportionately fails to identify high earners in that group - and if such a model
% were used to target a programme or allocate a resource, that gap would become a
% distributional harm.
%
% Two mechanisms usually drive this, and they call for different responses:
%
% * BASE RATES DIFFER across groups. Naive Bayes multiplies in P(sex | class), so a
%   group with a lower observed rate of high earnings is pushed toward the low-income
%   prediction for that reason alone.
% * SAMPLE SIZE DIFFERS. Smaller groups have noisier likelihood estimates, and Laplace
%   smoothing pulls them harder toward uniform (adding 1 to a denominator of 200 matters
%   more than adding 1 to a denominator of 20,000).
%
% Worth trying: refit without sex and race and see what happens to the gaps. Removing a
% protected attribute often does NOT close them, because correlated features such as
% occupation and relationship carry the same information. "Fairness through unawareness"
% mostly does not work, and this dataset shows it cleanly.

%% 3.11 What would we conclude?
% Stated as a researcher would state it:
%
%   Using twelve demographic and employment characteristics from the 1994 CPS, a Naive
%   Bayes classifier separates individuals earning above and below $50,000 substantially
%   better than chance, and comparably to logistic regression, despite strongly violated
%   independence assumptions among its predictors. Educational credentials and
%   occupational category carry the largest evidence weights, in an ordering consistent
%   with stratification research. The model's probability estimates are poorly
%   calibrated, concentrating near 0 and 1; they are usable for ranking but not as risk
%   estimates. Recall varies across sex and racial groups, reflecting differences in
%   both base rates and estimation precision.
%
% What it does NOT license:
%
% * No causal claim. Nothing here establishes that a credential CAUSES higher earnings.
% * No claim about today. These are 1994 associations at a 1994 dollar threshold.
% * No claim about the population without weights. fnlwgt exists for a reason and we
%   ignored it, as nearly everyone using this dataset does. A published analysis should
%   not.

%% Closing
% CHOOSING AN APPROACH IN MATLAB
%
% * All predictors categorical -> fitcnb with 'DistributionNames','mvmn', or nbFit below
%   if you need smoothing.
% * Continuous predictors, plausibly normal within class -> 'normal'.
% * Continuous but clearly not normal -> 'kernel', or bin with discretize as we did for
%   capital_gain. MATLAB's kernel option has no direct scikit-learn equivalent and is
%   genuinely useful here.
% * Mixed types -> pass a cell array of distribution names, one per predictor. This is
%   more convenient than Python or R, where mixing needs binning or manual combination.
% * Count data (text) -> 'mn'.
%
% MISTAKES THAT COST PEOPLE MARKS AND PAPERS
%
%  1. Assuming fitcnb smooths. It does not, and there is no argument to make it. An
%     empty cell yields an exact zero and a degenerate posterior.
%  2. Leaving an integer-coded category numeric. With 'normal' - or with 'mvmn' if the
%     codes are not contiguous - you get nonsense. Convert to categorical explicitly.
%  3. Letting MATLAB sort your category levels. Pass a valueset to categorical().
%  4. Forgetting that discretize bins are left-closed [a,b) while R's cut is
%     right-closed (a,b]. Ported edges silently shift a category.
%  5. Using a class label like '<=50K' as a table variable name. It is not a valid
%     identifier and the error appears far from the cause.
%  6. Misreading DistributionParameters. It is indexed {class, predictor} and each cell
%     is a vector over levels - a different layout from both Python and R. Print it and
%     check the columns sum to 1.
%  7. Reporting accuracy on imbalanced data. Always put the majority baseline beside it.
%  8. Treating the probabilities as calibrated. Rank with them; do not quote them.
%  9. Reading a likelihood ratio as a causal effect. It is a marginal association with
%     nothing held constant.
% 10. Including two features that encode the same thing (education and education_num).
%     Multiplying likelihoods counts that evidence twice.
%
% THE THREE LANGUAGES, SIDE BY SIDE
%
%                       scikit-learn        R e1071           MATLAB fitcnb
%   smoothing default   alpha = 1           laplace = 0       none, and no option
%   matches the slides  no                  yes               yes
%   zero likelihoods    left as 0           patched to 1e-3   left as 0
%   categorical input   encode to integers  automatic         automatic
%   mixing distributions bin or combine     bin or combine    cell array, built in
%
% EXERCISES
%
% 1. In Example 2, add a fourth predictor of your own invention to the 14 rows and see
%    how far the posterior for the test case moves. How many predictors can 14 rows
%    support?
% 2. Re-run section 3.10 after dropping sex and race from CAT. Does the subgroup recall
%    gap close? Explain what you find.
% 3. Sweep alpha over the Adult data as we did for the 14-row dataset. Why is the curve
%    so much flatter?
% 4. Replace the age_band and hours_band edges with equal-width bins
%    (discretize(x, 6)) and then with deciles (discretize(x, prctile2(x, 0:10:100))).
%    How much does AUC move? What does that tell you about how much the binning choice
%    mattered?
% 5. Refit Example 3 with 'DistributionNames' set to 'kernel' on the raw numeric age,
%    hours_per_week, capital_gain and capital_loss, mixed with 'mvmn' on the
%    categoricals. Does the kernel estimate beat our binning? This is the one thing
%    MATLAB does more easily than the other two languages - use it.
% 6. Implement Platt scaling: fit a logistic regression of the outcome on the Naive
%    Bayes log-odds using a validation split. Does the Brier score improve? Does AUC
%    change, and why not?

%% ------------------------------------------------------------------------
%% Local functions
% Everything below is plain MATLAB - no toolbox required. Local functions must appear
% at the end of a script file (R2016b or later).

function [F, rowLevels, colLevels] = freqTable(x, yy)
% Contingency table of two categorical vectors, in category order.
rowLevels = categories(x);
colLevels = categories(yy);
F = zeros(numel(rowLevels), numel(colLevels));
for i = 1:numel(rowLevels)
    for j = 1:numel(colLevels)
        F(i, j) = sum(x == rowLevels{i} & yy == colLevels{j});
    end
end
end

function T = withMargins(F, rowLevels, colLevels)
% Add a Total row and a Total column, then wrap in a table for display.
M = [F, sum(F, 2); sum(F, 1), sum(F(:))];
% VariableNames must be a 1-by-N cell array; categories() returns N-by-1.
T = array2table(M, 'RowNames', [rowLevels(:); {'Total'}], ...
                'VariableNames', [colLevels(:)', {'Total'}]);
end

function T = countcatsTable(c)
% Category counts as a one-row table, for readable display.
T = array2table(countcats(c)', 'VariableNames', ...
                matlab.lang.makeValidName(categories(c))');
end

function [post, labels] = nbByHand(X, yy, values, alpha, verbose)
% Naive Bayes for ONE observation, written out longhand.
%   X       table of categorical predictors
%   yy      categorical response
%   values  cell array of level names, one per predictor, same order as X
%   alpha   Laplace smoothing (0 = raw counts, as in the slides)
% Returns posteriors aligned with labels = categories(yy).
labels = categories(yy);
feats  = X.Properties.VariableNames;
n      = height(X);
scores = zeros(numel(labels), 1);

for c = 1:numel(labels)
    mask = (yy == labels{c});
    nc   = sum(mask);
    s    = nc / n;                                   % the prior P(c)
    txt  = sprintf('P(%s)=%.3f', labels{c}, s);

    for k = 1:numel(feats)
        levs = categories(X.(feats{k}));
        kk   = numel(levs);                          % k, for the smoothing denominator
        cnt  = sum(mask & X.(feats{k}) == values{k});
        lk   = (cnt + alpha) / (nc + alpha * kk);
        s    = s * lk;
        txt  = [txt sprintf(' x P(%s=%s|%s)=%.3f', ...
                            feats{k}, values{k}, labels{c}, lk)];   %#ok<AGROW>
    end

    scores(c) = s;
    if verbose
        fprintf('  %s = %.6f\n', txt, s);
    end
end

tot = sum(scores);
if tot == 0
    if verbose
        fprintf('  every class scored exactly 0 - undefined\n');
    end
    post = nan(size(scores));
else
    post = scores / tot;
end
end

function model = nbFit(X, yy, alpha)
% Fit a categorical Naive Bayes on a whole table. The "model" is just the tables.
model.features = X.Properties.VariableNames;
model.labels   = categories(yy);
model.alpha    = alpha;
model.prior    = zeros(numel(model.labels), 1);
model.levels   = cell(numel(model.features), 1);
model.lik      = cell(numel(model.features), 1);   % each: nLevels x nClasses

n = height(X);
for c = 1:numel(model.labels)
    model.prior(c) = sum(yy == model.labels{c}) / n;
end

for k = 1:numel(model.features)
    levs = categories(X.(model.features{k}));
    model.levels{k} = levs;
    P = zeros(numel(levs), numel(model.labels));
    for c = 1:numel(model.labels)
        mask = (yy == model.labels{c});
        nc   = sum(mask);
        col  = X.(model.features{k})(mask);
        cnts = countcats(col);                     % counts in category order
        P(:, c) = (cnts + alpha) / (nc + alpha * numel(levs));
    end
    model.lik{k} = P;
end
end

function [pred, post] = nbPredict(model, X)
% Predict with the model from nbFit. Works in LOG space: summing logs instead of
% multiplying probabilities is what keeps this from underflowing to zero once you have
% more than a handful of predictors.
nObs = height(X);
nCls = numel(model.labels);
logJoint = repmat(log(model.prior)', nObs, 1);

for k = 1:numel(model.features)
    levs = model.levels{k};
    idx  = zeros(nObs, 1);
    colVals = X.(model.features{k});
    for i = 1:numel(levs)
        idx(colVals == levs{i}) = i;
    end
    assert(all(idx > 0), 'unseen level in predictor %s', model.features{k});
    logJoint = logJoint + log(model.lik{k}(idx, :));
end

% Normalise with the log-sum-exp trick, again for numerical safety.
m = max(logJoint, [], 2);
w = exp(logJoint - m);
post = w ./ sum(w, 2);

[~, whichCls] = max(post, [], 2);
pred = categorical(model.labels(whichCls), model.labels);
end

function C = contributionTable(X, yy, values, alpha)
% Break one prediction into its per-feature evidence ratios.
labels = categories(yy);
feats  = X.Properties.VariableNames;
n      = height(X);

% strcat() strips trailing whitespace from char arguments, which would give
% 'Age =Senior'. sprintf via cellfun avoids that.
terms = [{'prior'}; cellfun(@(f, v) sprintf('%s = %s', f, v), ...
                            feats(:), values(:), 'UniformOutput', false)];
vals  = zeros(numel(terms), numel(labels));

for c = 1:numel(labels)
    mask = (yy == labels{c});
    nc = sum(mask);
    vals(1, c) = nc / n;
    for k = 1:numel(feats)
        levs = categories(X.(feats{k}));
        cnt  = sum(mask & X.(feats{k}) == values{k});
        vals(k + 1, c) = (cnt + alpha) / (nc + alpha * numel(levs));
    end
end

C = array2table(round(vals, 4), 'RowNames', terms, ...
                'VariableNames', matlab.lang.makeValidName(labels(:))');
C.ratio_Yes_No = round(vals(:, 2) ./ vals(:, 1), 3);
end

function E = evidenceWeights(model, feature, minShare)
% Log-likelihood ratio for each category of one feature, from an nbFit model.
k = find(strcmp(model.features, feature), 1);
assert(~isempty(k), 'feature %s not in model', feature);

P = model.lik{k};                       % nLevels x nClasses, classes in model.labels
levs = model.levels{k};
pLow  = P(:, 1);
pHigh = P(:, 2);
w = log(pHigh ./ pLow);

keep = max(pLow, pHigh) >= minShare;
E = table(round(pLow(keep), 3), round(pHigh(keep), 3), round(w(keep), 3), ...
          'RowNames', levs(keep), ...
          'VariableNames', {'p_given_low','p_given_high','evidence_weight'});
E = sortrows(E, 'evidence_weight', 'descend');
end

function a = aucScore(yy, s)
% AUC via the rank-based Mann-Whitney identity, with average ranks for ties.
% tiedrank() is a Statistics Toolbox function, so ranks are computed by hand.
yy = yy(:); s = s(:);
n = numel(s);
[ss, ord] = sort(s);
r = zeros(n, 1);
i = 1;
while i <= n
    j = i;
    while j < n && ss(j + 1) == ss(i)
        j = j + 1;
    end
    r(ord(i:j)) = (i + j) / 2;          % average rank across the tied block
    i = j + 1;
end
np = sum(yy == 1);
nn = sum(yy == 0);
if np == 0 || nn == 0
    a = NaN;
    return;
end
a = (sum(r(yy == 1)) - np * (np + 1) / 2) / (np * nn);
end

function [fpr, tpr] = rocPoints(yy, s)
% ROC curve without perfcurve.
[~, ord] = sort(s, 'descend');
lab = yy(ord);
tpr = [0; cumsum(lab == 1) / sum(lab == 1)];
fpr = [0; cumsum(lab == 0) / sum(lab == 0)];
end

function R = classificationReport(truth, pred, positive)
% Accuracy, balanced accuracy, precision, recall, F1 and the confusion matrix.
isPosT = (truth == positive);
isPosP = (pred  == positive);
tp = sum( isPosT &  isPosP);
fp = sum(~isPosT &  isPosP);
fn = sum( isPosT & ~isPosP);
tn = sum(~isPosT & ~isPosP);

R.confusion = [tn fp; fn tp];           % rows = actual neg/pos, cols = pred neg/pos
R.accuracy  = (tp + tn) / numel(truth);
recall      = safeDiv(tp, tp + fn);
specificity = safeDiv(tn, tn + fp);
R.balancedAccuracy = mean([recall specificity]);
R.precision = safeDiv(tp, tp + fp);
R.recall    = recall;
R.f1        = safeDiv(2 * R.precision * recall, R.precision + recall);
end

function out = safeDiv(a, b)
if b == 0 || isnan(b)
    out = NaN;
else
    out = a / b;
end
end

function T = calibrationTable(pHat, yy, nBins)
% Bucket predictions and compare the mean prediction to the observed rate.
edges = linspace(0, 1, nBins + 1);
bin = discretize(pHat, edges);
rows = {}; n = []; mp = []; ar = [];
for b = 1:nBins
    m = (bin == b);
    if ~any(m), continue; end
    rows{end+1, 1} = sprintf('(%.1f, %.1f]', edges(b), edges(b + 1));  %#ok<AGROW>
    n(end+1, 1)  = sum(m);                                             %#ok<AGROW>
    mp(end+1, 1) = mean(pHat(m));                                      %#ok<AGROW>
    ar(end+1, 1) = mean(yy(m));                                        %#ok<AGROW>
end
T = table(n, round(mp, 3), round(ar, 3), round(mp - ar, 3), 'RowNames', rows, ...
          'VariableNames', {'n','mean_predicted','actual_rate','gap'});
end

function T = subgroupReport(groups, truth, pred, positive)
% Per-group base rate, prediction rate, recall, false positive rate and accuracy.
levs = categories(removecats(groups));
name = {}; n = []; tr = []; pr = []; rc = []; fp = []; ac = [];
for i = 1:numel(levs)
    m = (groups == levs{i});
    t = truth(m); p = pred(m);
    posT = (t == positive);
    name{end+1, 1} = levs{i};                                          %#ok<AGROW>
    n(end+1, 1)  = sum(m);                                             %#ok<AGROW>
    tr(end+1, 1) = mean(posT);                                         %#ok<AGROW>
    pr(end+1, 1) = mean(p == positive);                                %#ok<AGROW>
    if any(posT)
        rc(end+1, 1) = mean(p(posT) == positive);                      %#ok<AGROW>
    else
        rc(end+1, 1) = NaN;                                            %#ok<AGROW>
    end
    if any(~posT)
        fp(end+1, 1) = mean(p(~posT) == positive);                     %#ok<AGROW>
    else
        fp(end+1, 1) = NaN;                                            %#ok<AGROW>
    end
    ac(end+1, 1) = mean(t == p);                                       %#ok<AGROW>
end
T = table(n, round(tr, 3), round(pr, 3), round(rc, 3), round(fp, 3), round(ac, 3), ...
          'RowNames', name, 'VariableNames', ...
          {'n','true_rate','predicted_rate','recall','FPR','accuracy'});
T = sortrows(T, 'n', 'descend');
end

function v = cramersV(a, b)
% Cramer's V from the contingency table. Chi-squared computed directly, so this needs
% no Statistics Toolbox.
la = categories(removecats(a));
lb = categories(removecats(b));
O = zeros(numel(la), numel(lb));
for i = 1:numel(la)
    for j = 1:numel(lb)
        O(i, j) = sum(a == la{i} & b == lb{j});
    end
end
n = sum(O(:));
if n == 0 || numel(la) < 2 || numel(lb) < 2
    v = NaN;
    return;
end
E = sum(O, 2) * sum(O, 1) / n;
keep = E > 0;
chi2 = sum(((O(keep) - E(keep)).^2) ./ E(keep));
v = sqrt((chi2 / n) / max(1, min(numel(la) - 1, numel(lb) - 1)));
end

function q = prctile2(x, pct)
% Percentiles by linear interpolation, so prctile() (Statistics Toolbox) is not needed.
x = sort(x(~isnan(x)));
n = numel(x);
if n == 0
    q = nan(size(pct));
    return;
end
% positions matching MATLAB's prctile convention
pos = pct(:) / 100 * n - 0.5 + 1;
pos = min(max(pos, 1), n);
lo = floor(pos); hi = ceil(pos); frac = pos - lo;
q = x(lo) .* (1 - frac) + x(hi) .* frac;
q = reshape(q, size(pct));
end

function c = lumpRare(c, minCount)
% Merge categories with fewer than minCount observations into 'Other'.
levs = categories(c);
cnt  = countcats(c);
rare = levs(cnt < minCount);
if isempty(rare)
    c = removecats(c);
    return;
end
if ismember('Other', levs)
    rare = unique([rare; {'Other'}]);
end
if numel(rare) == 1 && ~ismember('Other', levs)
    c = renamecats(c, rare{1}, 'Other');
else
    c = mergecats(c, rare, 'Other');
end
c = removecats(c);
end

function s = addThousandsSep(n)
% 32561 -> '32,561'. Purely cosmetic.
s = regexprep(sprintf('%d', n), '\d{1,3}(?=(\d{3})+$)', '$0,');
end
