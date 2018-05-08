desc "Scans Freelancer jobs, but just the first page of results so should be run often. Runs for 5 minutes"
task flancer: :environment do
  begin
    twelve_hour_clock_time = '%m-%d-%Y %I:%M:%S %p'
    time = Time.new
    Rails.logger.info "[Flancer Rake Task] starting  " + ' @ ' + time.strftime(twelve_hour_clock_time)

    eeid = ENV['EEID'] or raise "no EEID set for task"
    Rails.logger.info "[Flancer Rake Task] EEID = " + eeid.to_s


    f = Flancer::FreelanceManager.new

    loop_max_time = 300 #5 minutes
    time_start = Time.new # start time to compare how many seconds go by
    time_test = Time.new #initialize the end time for entry into the loop

    Rails.logger.info "[Flancer Rake Task] [logged] starting loop, the max loop time is #{loop_max_time.to_s} "

    while time_test - time_start <= loop_max_time

      if Flancer::has_command(eeid: eeid.to_i, command: 'stop')
        Rails.logger.info "[Flancer Rake Task] Got Stop Command "
        break
      end


      f.scrape_jobs(b_close_driver: false)
      Rails.logger.info "[Flancer Rake Task] Sleeping 20 seconds. Start time is #{time_start.to_s} loop time is #{time_test.to_s}"
      sleep 20
      Rails.logger.info "[Flancer Rake Task] woke up "

      time_test = Time.new
    end
    time = Time.new
    Rails.logger.info "[Flancer Rake Task] stopping naturally  " + ' @ ' + time.strftime(twelve_hour_clock_time)

  rescue => e
    Rails.logger.fatal "[Flancer Rake Task]  \n" + e.to_s
    unless f.blank?
      f.process_exception(exception: e, extra_message: "from rake task")
    end
  ensure
    f.clean_up unless f.blank? #close driver when exiting
  end

end

