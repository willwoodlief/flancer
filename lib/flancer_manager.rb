module Flancer

  require 'selenium-webdriver'

  mattr_accessor :list_of_managers, :commands
  self.list_of_managers = {}  #does nothing right now but keep track of things in the process
  self.commands = {}

  # noinspection RubyUnusedLocalVariable
  def self.has_command(eeid:, command:)
    return false  #stub this for later
  end



  class FreelanceManager
    attr_reader :driver, :eeid
    attr_accessor :user_name, :user_password, :b_stop_action

    def initialize(b_no_eeid:false)
      @user_name = Flancer::user_name
      @user_password = Flancer::user_password
      @b_stop_action = false

      if b_no_eeid
        @eeid = nil
      else
        @eeid =  ENV['EEID'] or Rails.logger.warn "[flancer] EEID is not set in environment"
        Flancer::list_of_managers[@eeid.to_i] = self
      end


      @driver = nil
    end

    def clean_up
      close_driver
      Flancer::list_of_managers.delete(@eeid) unless @eeid.blank?
    end

    def process_exception(exception:, files: {snapshot: nil, html: nil},extra_message:nil)
      unless ENV.key? 'EEID'
        Rails.logger.info "Cannot process exception without a EEID, this can occur within specs"
        return
      end

      Rails.logger.warn "[flancer] EEID is not set in environment" if ENV['EEID'].blank?
      eeid =  ENV['EEID']

      package = {eeid: eeid,exception: exception,files: files,extra_message: extra_message}
      ActiveSupport::Notifications.instrument('notify_exception', options: { extra: package })
      Rails.logger.info "[flancer] sent message and logged"
    end

    def scrape_jobs(b_close_driver:true)
      Rails.logger.info '[Flancer] Starting Scrape Jobs'
      return scrape_for_new(b_close_driver: b_close_driver)
    end

    def is_logged_in(b_log:false)
      if @driver.blank?
        Rails.logger.warn '[Flancer] ' + "Logger is blank when checking if logged in"
        return false
      end

      wait = Selenium::WebDriver::Wait.new(timeout: 5)
      begin
        wait.until {driver.find_elements(:partial_link_text, "My Projects").count > 0}
        Rails.logger.info '[Flancer] ' + "Is Logged In"
        return true
      rescue Selenium::WebDriver::Error::TimeOutError => toe
        Rails.logger.info '[Flancer] ' + "Did not find the link: My Projects"
        if b_log
          files = take_snapshot(stem:'did_not_find_my_projects')
          process_exception(exception: toe,files: files)
        end

        return false
      end

    end


    #gets new postings, enters them into the database, and returns the number of new things added
    # @return [Array<FreelanceScanner::FreelancerJob>]
    def scrape_for_new(b_close_driver:true)
      begin
        login_freelancer unless is_logged_in
        jobs = scan_projects
        return jobs
      rescue => e
        ts = Time.now.to_i
        Rails.logger.warn '[Flancer] ' + "Going to close driver due to exception"
        Rails.logger.error '[Flancer] ' + "[#{ts}] " + e.full_message
        files = take_snapshot(stem:'on_error',timestamp: ts)
        process_exception(exception: e,files: files)
        self.close_driver
        raise
      end

    ensure
      if b_close_driver
        Rails.logger.info '[Flancer] ' + "Closing driver in scrape for new because flag said so"
        close_driver
      end

    end

    def take_snapshot(stem: 'snapshot',timestamp:nil)
      return {snapshot: nil, html: nil} if @driver.blank?
      timestamp = Time.now.to_i if timestamp.nil?
      page_html = @driver.page_source
      name = "/tmp/#{timestamp}_#{stem}"
      snapshot_file_name = name + ".png"
      html_file_name = name + ".html"
      File.open(html_file_name, "w").write(page_html)
      @driver.save_screenshot(snapshot_file_name)
      return {snapshot: snapshot_file_name, html:html_file_name }
    end


    def self.get_post_counts(start_range_ts: nil, end_range_ts: nil)
      where_array = []
      param_hash = {}

      if start_range_ts && end_range_ts
        where_array << "( UNIX_TIMESTAMP(created_at) between :start_ts and :end_ts)"
        param_hash[:start_ts] = start_range_ts
        param_hash[:end_ts] = end_range_ts
      elsif end_range_ts
        where_array << "( UNIX_TIMESTAMP(created_at) <= :end_ts)"
        param_hash[:end_ts] = end_range_ts
      elsif start_range_ts
        where_array << "( UNIX_TIMESTAMP(created_at) >= :start_ts )"
        param_hash[:start_ts] = start_range_ts
      end

      where_array << "( is_read = :b_read )"
      param_hash[:b_read] = 1



      where_sql = where_array.join(' AND ')

      read_count = Flancer::FreelancerJob.where(where_sql, param_hash).count

      param_hash[:b_read] = 0
      unread_count = Flancer::FreelancerJob.where(where_sql, param_hash).count

      return {read: read_count, unread_count:unread_count}
    end

    # always ordered by the time posted
    # @param ts_start [nil|Integer] set to an integer to have results start from there (inclusive)
    # @param ts_end [nil|Integer] set to an integer to have results end at there (inclusive)
    # @param b_read [Boolean|nil] if nil then get both, else get one type
    # @param star_color [String] integers rgb hex of color
    # @param star_symbol [String] strings of star symbols
    # @param page [Integer], 1 based array starts at one
    # @param per_page [Integer], number of results per page
    # @param order_by [String]
    # @param order_dir [String]
    def self.get_posts(ts_start: nil, ts_end: nil, b_read: false, star_color: nil, star_symbol: nil,
                  comment_fragment: nil,filter:nil, page: 1, per_page: 100,
                  order_by: 'id', order_dir: 'desc')

      unless order_dir == "desc"
        order_dir == "asc"
      end



      order_string = order_by + ' ' + order_dir

      where_array = []
      param_hash = {}

      if ts_start && ts_end
        where_array << "( UNIX_TIMESTAMP(created_at) between :start_ts and :end_ts)"
        param_hash[:start_ts] = ts_start
        param_hash[:end_ts] = ts_end
      elsif ts_end
        where_array << "( UNIX_TIMESTAMP(created_at) <= :end_ts)"
        param_hash[:end_ts] = ts_end
      elsif ts_start
        where_array << "( UNIX_TIMESTAMP(created_at) >= :start_ts )"
        param_hash[:start_ts] = ts_start
      end

      if b_read === true
        where_array << "( is_read = :b_read )"
        param_hash[:b_read] = 1
      elsif b_read === false
        where_array << "( is_read = :b_read )"
        param_hash[:b_read] = 0
      end

      unless comment_fragment.blank?
        where_array << "( comments like concat('%',:comment_fragment,'%' ) )"
        param_hash[:comment_fragment] = comment_fragment
      end

      unless filter.blank?
        where_array << "( tags like concat('%',:filter_fragment,'%' ) )"
        param_hash[:filter_fragment] = filter
      end

      if star_color
        where_array << "( star_color = :star_color )"
        param_hash[:star_color] = star_color
      end

      if star_symbol
        where_array << "( star_symbol = :star_symbol )"
        param_hash[:star_symbol] = star_symbol
      end

      if where_array.blank?
        where_array << '1'
      end

      where_sql = where_array.join(' AND ')


      # noinspection RubyScope
      total_pages = Flancer::FreelancerJob.all.page(1).per(per_page).total_pages
      ar = Flancer::FreelancerJob.where(where_sql, param_hash).order(order_string).page(page).per(per_page)

      return {results: ar, meta: {page: page.to_i, total_pages: total_pages.to_i, per_page: per_page.to_i }}

    end

    # updates a post by its internal id
    # @param id [ integer] the primary key of how this is stored, can be array to mark a lot
    # @param b_read [Boolean] mark this as read(or not)
    # @param star_color [Integer] rgb hex color of star, if nil then star is not colored
    # @param star_symbol [String] a one character symbol to show the star
    # @param comment [String] add or edit a comment
    def self.update_post(id:, b_read: false, star_color: nil, star_symbol: nil, comment: nil)

      job =  Flancer::FreelancerJob.find(id)
      job.is_read = b_read  unless b_read.nil?
      job.star_color = star_color unless star_color.nil?
      job.star_symbol= star_symbol unless star_symbol.nil?
      job.comments = comment unless comment.nil?
      job.save
    end

    def close_driver
      Rails.logger.info '[Flancer] ' + "Closing Driver and making it blank"
      @driver.quit unless @driver.blank?
      @driver = nil
    end

    # @return [Array<Flancer::FreelancerJob>]
    def scan_projects
      results = []
      raise "Driver not initiated" if @driver.blank?
      driver = @driver
      Rails.logger.info '[Flancer] Going to https://www.freelancer.com/search/projects/'
      driver.get('https://www.freelancer.com/search/projects/')
      wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
      sleep 5
      begin
        wait.until {driver.execute_script("return document.readyState;") == 'complete'}
      rescue Selenium::WebDriver::Error::TimeOutError => timed
        Rails.logger.error '[Flancer] ' + "Could not wait until page completed"
        raise timed   # do not need to process or take snapshot the handler above will do that
      end
      #minimize chat box
      button_xpath = "/html/body/webapp-compat/webapp-compat-messaging/app-messaging/app-messaging-contacts/app-header/div[2]/fl-icon[2]"
      button_to_press = driver.find_element(:xpath, button_xpath)
      button_to_press.click
      sleep 2


      displayed_rows = driver.find_elements(:xpath, "//ul[contains(@class, 'search-result-list')]//li[contains(@class,'search-result-item')]")
      Rails.logger.info '[Flancer] ' + "Found rows: " + displayed_rows.count.to_s
      displayed_rows.each do |row|
        begin
          Rails.logger.info '[Flancer] ' + "starting row"
          job = nil
          title_div_array = row.find_elements(:xpath,"fl-project-tile/div[contains(@class,'info-card-inner')]/div[contains(@class,'info-card-title')]")
          if title_div_array.count != 1
            raise "more than one title div in: " + row.attribute("innerHTML")
          end
          title_div = title_div_array.first

          anchor = title_div.find_element(tag_name: 'a')
          link_url = anchor.attribute('href')
          Rails.logger.info '[Flancer] ' + 'url: ' + link_url

          # @type [Flancer::FreelancerJob] job
          job = Flancer::FreelancerJob.find_or_create_by(link: link_url)
          job.title = title_div.text
          job.link = link_url
          job.description  = row.find_element(:xpath,"fl-project-tile/div/p[contains(@class,'info-card-description')]").text
          Rails.logger.info '[Flancer] ' + "title: " + job.title
          Rails.logger.info '[Flancer] ' + 'description: ' + job.description
          skills_ul = row.find_element(:xpath,"fl-project-tile/div/ul[contains(@class,'info-card-skills')]")
          tags = tags = skills_ul.find_elements(:xpath, "li")
          tag_array = []
          tags.each do |tag|
            tag_array << tag.text
          end
          job.tags = tag_array.join(', ')
          Rails.logger.info '[Flancer] ' + 'tags: ' + job.tags
          action_div = row.find_element(:xpath,"fl-project-tile/div[contains(@class,'info-card-action')]")
          prices = action_div.find_elements(:xpath,"div[contains(@class,'info-card-price')]")
          job.price_hint = prices.first.text + ' ' + prices.last.text
          job.number_bids = row.find_element(:class_name,"info-card-bids").text
          Rails.logger.info '[Flancer] ' + 'number bids: ' + job.number_bids
          job.save
          Rails.logger.info '[Flancer] ' + "saved: " + job.id.to_s
          results << job
        rescue Selenium::WebDriver::Error::NoSuchElementError => ns
          Rails.logger.warn '[Flancer] ' + ns.message
          Rails.logger.warn job
          files = take_snapshot(stem:'missing_element')
          process_exception(exception: ns,files: files)
        end
      end
      return results
    end


    # @return [Array<Flancer::FreelancerJob>]
    def scan_results_page
      results = []
      s = @driver.find_element(:id, 'quantity-selector')
      r = Selenium::WebDriver::Support::Select.new(s)
      r.select_by(:text, '100')
      sleep 2
      displayed_rows = driver.find_elements(:xpath, "//table[@id='project_table']//tbody/tr\[not(contains(@style,'display: none'))]")
      displayed_rows.each do |row|
        begin
          internal_id = row.attribute('project_id')
          # @type [Flancer::FreelancerJob] job
          job = Flancer::FreelancerJob.find_or_create_by(internal_id: internal_id)
          title_link_element = row.find_elements(:xpath, 'td/h2/a').first
          job.title = title_link_element.text
          job.link = title_link_element.attribute('href')
          skills = row.find_elements(:xpath, "td/span[contains(@class,'ProjectTable-skills')]").first
          tags = skills.find_elements(:xpath, "a")
          tag_array = []
          tags.each do |tag|
            tag_array << tag.text
          end
          job.tags = tag_array.join(', ')
          job.description = row.find_elements(:xpath, "td/p[contains(@class,'ProjectTable-description')]").first.text
          job.number_bids = row.find_elements(:xpath, "td[contains(@class,'ProjectTable-bidsColumn')]").first.text
          job.when_posted = row.find_elements(:xpath, "td[contains(@class,'ProjectTable-startedColumn')]").first.text
          ps_element = row.find_elements(:xpath, "td[contains(@class,'ProjectTable-priceColumn')]").first
          job.price_hint = ps_element.find_elements(:xpath, "span[contains(@class,'average-bid')]").first.text
          status_span = ps_element.find_elements(:xpath, "div[contains(@class,'ProjectTable-status')]/span").first
          unless status_span.blank?
            job.status = status_span.attribute('data-content')
          end
          job.save
          results << job
        rescue Selenium::WebDriver::Error::NoSuchElementError => ns
          Rails.logger.warn '[Flancer] ' + ns.message
          Rails.logger.warn job
          files = take_snapshot(stem:'missing_element')
          process_exception(exception: ns,files: files)
        rescue => e
          Rails.logger.warn '[Flancer] ' + e.to_s
          Rails.logger.warn '[Flancer] ' + e.backtrace.join("\n")
          process_exception(exception: e)
        end
      end
      return results
    end

    def self.login_test
      options = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])
      #options = Selenium::WebDriver::Chrome::Options.new
      #options.add_option('debuggerAddress', '127.0.0.1:9222')
      driver = Selenium::WebDriver.for(:chrome, options: options)
      driver.manage.window.resize_to(1280, 800)
      wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
      driver.get('https://www.freelancer.com/login')


      begin
        wait.until {driver.execute_script("return document.readyState;") == 'complete'}
      rescue Selenium::WebDriver::Error::TimeOutError => timed
        Rails.logger.error '[Flancer] ' + "Could not wait until page completed"
        #test does not go with the framework, no need to capture errors
        raise timed
      end

      user_name = driver.find_element(id: 'username')

      user_name.send_keys(Flancer.user_name)


      begin
        password = driver.find_element(id: 'password')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        password = driver.find_element(id: 'passwd')
      end

      password.send_keys(Flancer.user_password)

      #toggle checkbox

      driver.find_elements(:class, "checkbox").first.click
      remember_me = driver.find_element(:id => "loginpermanent")
      unless remember_me.selected?
        raise "cannot check remember me"
      end


      #get button to click
      button_xpath = "//button[contains(text(),'Log In')]"
      button_to_press = driver.find_element(:xpath, button_xpath)
      button_to_press.click

      begin
        wait.until {driver.find_elements(:partial_link_text, "Dashboard").count > 0}
      rescue Selenium::WebDriver::Error::TimeOutError
        Rails.logger.warn '[Flancer] ' + "trying to click again"
        button_to_press = driver.find_element(:xpath, button_xpath)
        button_to_press.click
        begin
          wait.until {driver.find_elements(:partial_link_text, "Dashboard").count > 0}
        rescue Selenium::WebDriver::Error::TimeOutError
          Rails.logger.error '[Flancer] ' + "could not login"
          #test does not go with the framework, no need to capture errors
        end


      end
      return driver
    end

    # this logs in to the site, and returns a browser which can access protected pages
    # @return [Selenium::WebDriver::Driver|nil]
    def login_freelancer

      Rails.logger.info '[Flancer] ' + "Starting Login"
      unless @driver.blank?
        @driver.close_driver
        @driver = nil
      end

      timestamp = Time.now.to_i
      raise "need username and password" if @user_name.blank? || @user_password.blank?

      password = nil
      begin
        # settings for selenium used in this engine
        Rails.logger.info '[Flancer] Starting Web Driver'
        Selenium::WebDriver.logger.level = :warn
        options = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])

        # options.add_argument("user-data-dir=new_chrome_dir")

        @driver = Selenium::WebDriver.for(:chrome, options: options)
        driver = @driver


        wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
        driver.manage.window.resize_to(1280, 800)
        Rails.logger.info '[Flancer] Going to https://www.freelancer.com/login'
        driver.get('https://www.freelancer.com/login')

        sleep 5
        begin
          wait.until {driver.execute_script("return document.readyState;") == 'complete'}
        rescue Selenium::WebDriver::Error::TimeOutError => timed
          Rails.logger.error '[Flancer] ' + "Could not wait until page completed"
          raise timed
        end

        # Rails.logger.info "Login Page Console"
        # Rails.logger.info driver.manage.logs.available_types.to_s
        # log_entries = driver.manage.logs.get :browser
        # log_entries.each do | k , v|
        #   Rails.logger.info k.to_s . +'=>' +v.to_s;
        # end
        #
        # log_entries = driver.manage.logs.get :driver
        # log_entries.each do | k , v|
        #   Rails.logger.info k.to_s . +'=>' +v.to_s;
        # end
        #
        # driver.execute_script('window.jQuery( document ).ajaxSend(function( event, jqxhr, settings ) {
        #     console.log("AJAX Global => ",settings);
        #    });')


        user_name = driver.find_element(id: 'username')

        user_name.send_keys(Flancer.user_name)


        begin
          password = driver.find_element(id: 'password')
        rescue Selenium::WebDriver::Error::NoSuchElementError
          password = driver.find_element(id: 'passwd')
        end

        password.send_keys(Flancer.user_password)

        #toggle checkbox

        driver.find_elements(:class, "checkbox").first.click
        remember_me = driver.find_element(:id => "loginpermanent")
        unless remember_me.selected?
          raise "cannot check remember me"
        end


        #get button to click
        button_xpath = "//button[contains(text(),'Log In')]"
        button_to_press = driver.find_element(:xpath, button_xpath)
        button_to_press.click


        unless is_logged_in(b_log: false)
          Rails.logger.warn '[Flancer] ' + "Clicking login button again"
          button_to_press = driver.find_element(:xpath, button_xpath)
          button_to_press.click

          unless is_logged_in
            Rails.logger.error '[Flancer] ' + "Could not find dashboard in time after log in"
            raise "Could not log in"
          end
        end

        take_snapshot(stem: 'login_freelancer_success')
        return driver

# results = driver.find_element(id: 'results')

# results.find_elements(tag_name: 'h3').each do |h3|
#   Rails.logger.info h3.text.strip
# end
#
# body = driver.find_element(tag_name: "html")
# # Rails.logger.info body.attribute("innerHTML")
# Rails.logger.info "-----------------"
# driver.page_source

      rescue => e
        Rails.logger.error '[Flancer] ' + e.class.to_s
        Rails.logger.error '[Flancer] ' + e.message
        # noinspection RubyScope
        take_snapshot(stem: 'login_freelancer_on_error',timestamp: timestamp)
        log_browser_info
        raise
      ensure
        #driver.quit unless driver.nil?
        Rails.logger.info '[Flancer] ' + ">>>>>>>>>>>> login timestamp is #{timestamp.to_s}"
      end

    end

    def log_browser_info
      return if @driver.blank?
      Rails.logger.info '[Flancer] [Browser Errors and Warnings] ' + "browser errors"
      log_entries = @driver.manage.logs.get :browser
      log_entries.each do |k, v|
        Rails.logger.info '[Flancer][Browser Errors and Warnings] ' + k.to_s + '=>' + v.to_s;
      end
    end
  end

end