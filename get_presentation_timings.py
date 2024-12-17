import pandas as pd
import logging

def parse_log_file(log_file_path, start_trial_type, end_trial_type, trial_types):
    """
    Parses a log file to extract and compute trial information based on specified start and end trial markers,
    while excluding these markers from the final results. This function ensures that all specified trial types
    are present in the data, throwing warnings if not, and errors if start or end trial markers are missing.

    Args:
        log_file_path (str): Path to the log file.
        start_trial_type (str): The trial type marking the beginning of measurements.
        end_trial_type (str): The trial type marking the end of measurements.
        trial_types (tuple): A tuple of strings representing the trial types of interest.

    Returns:
        pd.DataFrame: A DataFrame with trials including number, type, adjusted onset times, and durations.

    Raises:
        ValueError: If the start or end trial types are not found, or if the data cannot be loaded.
    """
    # Initialize logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    # Load the data from the log file
    try:
        data = pd.read_csv(log_file_path, delimiter='\t', skiprows=[0,1,2,3])
    except Exception as e:
        logging.error(f"Failed to load data from log file: {e}")
        raise

    # Standardize case for matching
    data['name(str)'] = data['name(str)'].str.upper()
    start_trial_type = start_trial_type.upper()
    end_trial_type = end_trial_type.upper()

    # Check for the presence of required start and end trials
    if start_trial_type not in data['name(str)'].values or end_trial_type not in data['name(str)'].values:
        missing = [trial for trial in [start_trial_type, end_trial_type] if trial not in data['name(str)'].values]
        logging.error(f"Required trial types missing: {missing}")
        raise ValueError(f"Required trial types missing from the log file: {missing}")

    # Validate the presence of other specified trial types
    trial_types = tuple(t.upper() for t in trial_types)
    missing_types = set(trial_types) - set(data['name(str)'].values)
    if missing_types:
        logging.warning(f"Some specified trial types are not present in the log file: {missing_types}")

    # Filter the data to include only the desired trial types plus start and end markers
    relevant_trials = set(trial_types).union({start_trial_type, end_trial_type})
    filtered_data = data[data['name(str)'].isin(relevant_trials)]

    # Retrieve reference times for onset calculations
    start_time = data.loc[data['name(str)'] == start_trial_type, 'Time'].iloc[0]
    end_time = data.loc[data['name(str)'] == end_trial_type, 'Time'].iloc[0]

    # Select and rename the necessary columns
    filtered_data = filtered_data[['Trial', 'name(str)', 'Time']].rename(
        columns={'Trial': 'trial_num', 'name(str)': 'trial_type', 'Time': 'onset'})

    # Adjust the 'onset' times by subtracting the start time and scaling
    filtered_data['onset'] = (filtered_data['onset'] - start_time) / 10000

    # Calculate the duration between consecutive stimuli, including handling the last trial duration
    filtered_data['duration'] = filtered_data['onset'].diff(-1).abs()
    last_index = filtered_data.index[-1]
    filtered_data.at[last_index, 'duration'] = (end_time - filtered_data.at[last_index, 'onset'] * 10000) / 10000

    # Remove the start and end trial types from the final DataFrame
    filtered_data = filtered_data[(filtered_data['trial_type'] != start_trial_type) & (filtered_data['trial_type'] != end_trial_type)]

    return filtered_data

# Usage
log_file_path = "/home/eik-tb/Desktop/helena/bh_logs/sub-002/002-D2_5_ElectroHeat_Conditioning_COLA.log"
start_trial_type = 'fMRI_T0'
end_trial_type = 'END'
trial_types = ('VAS', 'FLANKER', 'FLANKER_PAUSE', 'ISI', 'PAIN', 'FIXATION', 'TRIGGER', 'PAUSE')
events_df = parse_log_file(log_file_path, start_trial_type, end_trial_type, trial_types)
print(events_df)
