
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% Script to extract onsets and durations from the Presentation logfiles %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Inititally written by Andrea Ivan Costantino (andreaivan.costantino@kuleuven.be) in May 2024
% Adapted by Helena Hartmann (helena.hartmann@uk-essen.de) in December 2024

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Define Variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% subjects = {'001'}; % for testing code with single subject
subjects = {'001','002','003','004','005','006','007','008','009','010',... % n = 67
            '011','012','013','014','015','016','017','018','019','020'};

% Two tasks: Conditioning and Test phase
tasks = {'task1','task2'}; 

% Define the input and output directory to get data and save results later
inputDir = 'Path to logfiles';
outputDir = 'Path to BIDS folder where data will be saved';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Loop through logfiles %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1st Loop: Subjects
for i = 1:length(subjects)

    clearvars -except subjects tasks inputDir outputDir i j; % clean up workspace for new subject

    % 2nd Loop: Tasks
    for j = 1:length(tasks)

        %%%%%%%%%%%%%%%%%%%% Define the task name %%%%%%%%%%%%%%%%%%%%
        if j == 1
            taskName = 'task1';
        elseif j == 2
            taskName = 'task2';
        end
       
        %%%%%%%%%%%% Define subjects numbers and names %%%%%%%%%%%%%%%

        subjectNumber = subjects{i}; % this is just the number itself, e.g. 001
        subjectName = sprintf('sub-%s', subjectNumber); % BIDS-conform "sub-" plus number zero-padded to three digits, e.g. sub-001
    
        %%%%%%%%%%%%% Create individual log file paths %%%%%%%%%%%%%%%

        if strcmp(taskName, 'task1') % for task1 runs
            
            % Define the path to the log file
            if ((strcmp(subjectNumber, '001')) || (strcmp(subjectNumber, '002'))) % these subjects use differently numbered runs/logfiles for cond
                fileName = sprintf('%s-Task1_2.log', subjectNumber); 
            else 
                fileName = sprintf('%s-Task1_1.log', subjectNumber); % for all other subjects
            end
       
            logFilePath = fullfile(inputDir,subjectName,fileName); % paste the full path to the data together from the variables
            
            % Define the run number
            if ((strcmp(subjectNumber, '001')) || (strcmp(subjectNumber, '002'))) % these subjects use different runs
                runNumber = '02';
            else 
                runNumber = '01'; % for all other subjects
            end
        
        elseif strcmp(taskName, 'task2') % for test runs

            % Define the path to the log file
            fileName = sprintf('%s-Task2.log', subjectNumber); % the same for all subjects
            logFilePath = fullfile(inputDir,subjectName,fileName); % paste the full path to the data together from the variables
            runNumber = '01'; % same run number for all subjects
        end
    
        %%%%%%%%%%%%%%%%%%%%%%% Define Events %%%%%%%%%%%%%%%%%%%%%%%
        
        % Define the start and end trial types
        startTrialType = 'FMRI_T0';
        endTrialType = 'END';
        
        % Define the trial types of interest
        trialTypes = {'EVENT1', 'EVENT2', 'EVENT3', 'EVENT4', 'EVENT5', 'EVENT6', 'EVENT7'};
        Triggers = {'TRIGGER'};

        %%%%%%%%%%%%%%%%%%%%%%% Call Function %%%%%%%%%%%%%%%%%%%%%%%
        
        % it also works without the function if you want to check the files after it has run, but you can use either (if you use the function, uncomment lines 97-118 and 236)
        
        %parseLogFile(logFilePath, startTrialType, endTrialType, trialTypes, outputDir, runNumber, Triggers);
        
        %function parseLogFile(logFilePath, startTrialType, endTrialType, trialTypes, outputDir, runNumber, Triggers)
            % Parses a log file to extract trial information with BIDS compatible naming for output files
            % Inputs:
            %   logFilePath - String, path to the log file
            %   startTrialType - String, trial type marking the beginning of measurements, e.g. the start of the first scanned volume
            %   endTrialType - String, trial type marking the end of measurements, e.g. when the task was stopped / the last event
            %   trialTypes - Cell array of strings, trial types of interest
            %   outputDir - String, root BIDS directory where the output file will be saved
            %   runNumber - String, run number formatted as two digits (default '01')
            %
            % The output filename is constructed using BIDS format:
            % 'sub-xxx_task-y_run-zz_events.tsv' where xxx is the subject number, y is the task name, and zz is the run number.
        
            % Set default values for optional parameters
            %if nargin < 7
            %    runNumber = '01'; % Default run number
            %end
            %if nargin < 6
            %    taskName = 'cond'; % Default task name
            %end

            %%%%%%%%%%%%%%%%%%%% Logfile Reading %%%%%%%%%%%%%%%%%%%%

            try
                % Read the log file
                opts = detectImportOptions(logFilePath, 'FileType', 'text', 'Delimiter', '\t');
                opts.VariableNamingRule = 'preserve'; % Preserve original headers
                data = readtable(logFilePath, opts); % Read in the datafile
                
                % Extract subject number from the 'Subject' column, expecting a single unique value
                if strcmp(subjectNumber, '001') % this subject is named wrong in the logfile, so take number from somewhere else
                    subjectNumber = subjects{i};
                else
                    subjectNumber = sprintf('%.3d', mode(data.Subject)); % Take number and make it zero-padded to three digits
                end
                
                % Convert trial type column to uppercase for case-insensitive matching
                data.('name(str)') = upper(data.('name(str)'));
                
                % Check for the presence of required start and end trials
                if ~any(ismember({upper(startTrialType), upper(endTrialType)}, data.('name(str)')))
                    error('Required start or end trial types are missing from the data.'); % if they're not there, throw an error
                end
                
                % Include start and end trial types in the list of trial types
                trialTypes = upper(trialTypes); % Ensure all types are uppercase
                trialTypes = [trialTypes, upper(startTrialType), upper(endTrialType)];
        
                %%%%%%%%%%% Filter data (except triggers) %%%%%%%%%%%%
        
                % Filter the data to only include desired trial types (except for the triggers)
                mask = ismember(data.('name(str)'), trialTypes);
                filteredData = data(mask, :);
                
                %%%%%%%%%%%%%%%% Filter trigger data %%%%%%%%%%%%%%%%%
                
                % Filter only the trigger data to remove excess triggers
                mask2 = ismember(data.('name(str)'), Triggers);
                filteredData_triggers = data(mask2, :);

                % filter out only the first of the triggers (as there are many triggers for the same event in the logfile)
                filteredData_finaltriggers = filteredData_triggers(filteredData_triggers.TTime <= 1, :);
        
                %%%%%%%%%%%%%%% Add all data together %%%%%%%%%%%%%%%%
                
                % add the final filtered trigger data back to the other data
                togetherData = vertcat(filteredData, filteredData_finaltriggers);
        
                % sort by trial number to get them in the right order
                finalData = sortrows(togetherData,2);

                %%%%%%%%%% Calculate onsets and durations %%%%%%%%%%%%
                
                % has to be calculated on the full data, so the onsets are in relation to all events (triggers and others)
                % Find reference times for onset calculations
                start_time = data.Time(strcmp(data.('name(str)'), upper(startTrialType)));
                end_time = data.Time(strcmp(data.('name(str)'), upper(endTrialType)));
       
                % Calculate onset times and durations
                finalData.onset = (finalData.Time - start_time) / 10000; % subtract T0 (time of first volume) from all onsets and convert to seconds (Presentation times are in 10ths of ms)
                finalData.duration = [diff(finalData.onset); (end_time - finalData.Time(end)) / 10000]; % convert to seconds (Presentation times are in 10ths of ms)
        
                %%%%%%%%%%%%%%%%%%% Final touches %%%%%%%%%%%%%%%%%%%%

                % Remove the start and end trial types from the final data
                finalData = finalData(~strcmp(finalData.('name(str)'), upper(startTrialType)) & ...
                                         ~strcmp(finalData.('name(str)'), upper(endTrialType)), :);
                
                % Select only the necessary columns and rename them
                finalData = finalData(:, {'Subject', 'Trial', 'name(str)', 'onset', 'duration'});
                finalData.Properties.VariableNames = {'subject', 'trial_num', 'trial_type', 'onset', 'duration'};

                % delete the last 6 trials from subject 006, as they only completed 30 trials with heat stimuli (rows 280-336)
                if (strcmp(subjectNumber, '006'))
                    finalData(280:336,:) = [];
                end

                %%%%%%%%%%%%%%%%%%%% Output File %%%%%%%%%%%%%%%%%%%%%
        
                % Construct the output filename based on BIDS specification
                outputFile = fullfile(outputDir,['sub-', subjectNumber], 'func',  ...
                    ['sub-', subjectNumber, '_task-', taskName, '_run-', runNumber, '_events.tsv']);
                
                % Save the final table to file as TSV
                writetable(finalData, outputFile, 'FileType', 'text', 'Delimiter', '\t');

                %%%%%%%%%%% Print status info to console %%%%%%%%%%%%
    
                % print information to console to doublecheck whether all data is there (can be modified to whatever you're interested in!)
                triggercount = nnz(filteredData_finaltriggers.TTime > 0);
                fprintf(sprintf('For subject %s and task "%s", I found %i events, %i initial triggers and %i have a TTime > 0. \n\n', subjectNumber, taskName, height(finalData), height(filteredData_finaltriggers), triggercount))
        
                %%%%%%%%%%%%%%%%%% Error catching %%%%%%%%%%%%%%%%%%%

            catch ME
                disp(fprintf('An error occurred for subject %s:\n',subjectNumber));
                disp([ME.message]);
            end

    end % Task loop

    %end % Function loop

end % Subject loop