# Simplified speedtest runner that just calls Ookla's Speed Test from the command
# line. It requires that the command line interface be installed first.
# See: https://www.speedtest.net/apps/cli

# Capture when the script started running. This is useful both to ensure that
# "internet down" results are recorded AND to help with reading the log files.
start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
# Output start time to console (and log it if running through cron)
cat("Speed test started at", start_time,"\n")

# Load required libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse,
               lubridate,
               jsonlite)      

# Set the file path for the logged results. Hard coding this so that, when
# running as a cron job, it still puts the results in the same location
# as the script.
results_loc <- "/Users/timwilson/R Projects/_personal_projects/speedtest-local/speedtest_log.csv"

# Run Speedtest CLI and capture output. Get the results as JSON 
df_speedtest_output <- system("/opt/homebrew/bin/speedtest -f json --accept-license", intern = TRUE) 

# If the internet is down, the above would not return any result, so make a row that is NAs
# for all values except the start time. Otherwise, clean up the results so those can be logged
if(length(df_speedtest_output) == 0){
  
  cat("Speed test started at", start_time, "failed to run.\n")
  
  output_log_entry <- data.frame(start_time = start_time,
                                 timestamp_utc = NA,
                                 timestamp_local_tz = NA,
                                 local_tz = NA,
                                 download_mbps = NA,
                                 download_latency_iqm_ms = NA, 
                                 download_latency_jitter_ms = NA,
                                 upload_mbps = NA,
                                 upload_latency_iqm_ms = NA, 
                                 upload_latency_jitter_ms = NA,
                                 result.url = NA)
} else {
  
  # Make a simplified data frame. "bandwidth" is provided in "bytes/sec",
  # so divide by 125,000 to get Mbps: 1 byte = 8 bits; 1 Mb = 1,000,000 bits
  output_log_entry <- df_speedtest_output |> 
    # Convert from JSON to a data frame
    fromJSON() |> 
    as.data.frame() |> 
    mutate(start_time = start_time,
           timestamp_utc = ymd_hms(timestamp),    # Date/time in UTC
           timestamp_local_tz = ymd_hms(as.character(ymd_hms(timestamp, tz = ""))), # Date/time in local timezone
           local_tz = Sys.timezone(), # The local timezone
           download_mbps = download.bandwidth/125000,  # Download bandwidth in Mbps
           upload_mbps = upload.bandwidth/125000       # Upload bandwidth in Mbps
    ) |> 
    select(start_time,
           timestamp_utc,
           timestamp_local_tz,
           local_tz,
           download_mbps,
           # Interquartile mean of download of packets in milliseconds
           download_latency_iqm_ms = download.latency.iqm, 
           # Variation in the latency of the download (higher # is worse) in milliseconds
           download_latency_jitter_ms = download.latency.jitter,
           upload_mbps,
           # Interquartile mean of upload of packets in milliseconds
           upload_latency_iqm_ms = upload.latency.iqm, 
           # Variation in the latency of the upload (higher # is worse) in milliseconds
           upload_latency_jitter_ms = upload.latency.jitter,
           # URL to view the results of the test in a browser
           result.url)
  
  cat("Speed test started at", start_time, "ran successfully. Output log entry created.\n")
  
}

# Append to the log of results (or create the file if it doesn't)
if(file.exists(results_loc)){
  current_log <- read_csv(results_loc)
  # Append the latest results
  update_log <- current_log |> 
    bind_rows(output_log_entry)
} else {
  update_log <- output_log_entry
}

# Write out the updated results
write_csv(update_log, results_loc)

cat("Speed test started at", start_time, "ran successfully. Results log updated.",
    "Script completed at",format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
