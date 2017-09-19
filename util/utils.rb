require 'hash_deep_merge'
require_relative 'spec_helper'

class Utils

  include Logging

  # Initiate hash (before YAML load) to leverage 'hash_deep_merge' gem. The deep_merge support allows the YAML file in
  # your HOME directory to override a child property (e.g., 'timeouts.short') and yet hold on to sibling properties
  # (e.g., 'timeouts.long') in the default YAML. A standard Hash.merge would cause us to lose the entire parent
  # structure ('timeouts') in the default YAML.
  @config = {}
  @config.merge! YAML.load_file File.path('settings.yml')
  @config.deep_merge! YAML.load_file File.join(ENV['HOME'], '/.webdriver-config/settings.yml')

  def self.config
    @config
  end

  # BROWSER CONFIGS

  # Instantiates the browser and alters default browser settings.
  def self.launch_browser
    driver = @config['webdriver']
    logger.info "Launching #{driver.capitalize}"
    if %w(firefox chrome safari).include? driver
      if driver == 'firefox'
        profile = Selenium::WebDriver::Firefox::Profile.new
        profile['browser.download.folderList'] = 2
        profile['browser.download.manager.showWhenStarting'] = false
        profile['browser.download.dir'] = Utils.download_dir
        profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/msword, application/vnd.ms-excel, application/vnd.ms-powerpointtd>, application/pdf, application/zip, audio/mpeg, image/png, image/bmp, image/jpeg, image/gif, image/sgi, image/svg+xml, image/webp, text/csv, video/mp4, video/quicktime'
        driver = Selenium::WebDriver.for :firefox, profile: profile
      elsif driver == 'chrome'
        profile = Selenium::WebDriver::Chrome::Profile.new
        profile['download.prompt_for_download'] = false
        profile['download.default_directory'] = Utils.download_dir
        profile['profile.password_manager_enabled'] = false
        profile['credentials_enable_service'] = false
        profile['password_manager_enabled'] = false
        driver = Selenium::WebDriver.for :chrome, profile: profile
      else
        driver = Selenium::WebDriver.for :safari
      end
      # If a specific window size is needed (e.g., Chrome or Safari on a small screen), set size. Else, maximize the window.
      width = @config['window']['width']
      height = @config['window']['height']
      (height.zero? || width.zero?) ?
          driver.manage.window.maximize :
          driver.manage.window.resize_to(width, height)
      driver
    else
      logger.error 'Designated WebDriver is not supported'
      nil
    end
  end

  # @param driver [Selenium::WebDriver]
  def self.quit_browser(driver)
    logger.info 'Quitting the browser'
    # If the browser did not start successfully, the quit method will fail.
    driver.quit rescue NoMethodError
    # Pause after quitting the browser to make sure it shuts down completely before the next test relaunches it
    sleep 2
  end

  # TIMEOUTS

  # How long to wait before clicking an element. Used to slow down or speed up test execution.
  def self.click_wait
    @config['timeouts']['click_wait']
  end

  def self.event_wait
    @config['timeouts']['event_wait']
  end

  # Short timeout intended for things like page DOM updates
  def self.short_wait
    @config['timeouts']['short']
  end

  # Moderate timeout intended for things like page loads
  def self.medium_wait
    @config['timeouts']['medium']
  end

  # Long timeout intended for things like large file uploads or asynchronous processes
  def self.long_wait
    @config['timeouts']['long']
  end

  # CALNET AND CANVAS

  # Base URL of CalNet authentication service test instance
  def self.cal_net_url
    @config['cal_net']['base_url']
  end

  # Base URL of Canvas test environment
  def self.canvas_base_url
    @config['canvas']['base_url']
  end

  # Canvas 'Admin' sub-account ID
  def self.canvas_admin_sub_account
    @config['canvas']['admin_sub_account']
  end

  # Canvas 'UC Berkeley' sub-account ID
  def self.canvas_uc_berkeley_sub_account
    @config['canvas']['uc_berkeley_sub_account']
  end

  # Canvas 'Official Courses' sub-account ID
  def self.canvas_official_courses_sub_account
    @config['canvas']['official_courses_sub_account']
  end

  # Canvas 'QA' sub-account ID
  def self.canvas_qa_sub_account
    @config['canvas']['qa_sub_account']
  end

  # TEST DATA, TEST RESULTS, UPLOADS

  # Returns the current datetime for use as a unique test identifier
  def self.get_test_id
    "#{Time.now.to_i}"
  end

  # Makes sure a directory exists for files generated by tests
  # @return [String]
  def self.initialize_test_output_dir
    output_dir = File.join(ENV['HOME'], '/tmp/test-output')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    output_dir
  end

  # Adds a row of data to a CSV
  # @param file [File]
  # @param values [Array<String>]
  def self.add_csv_row(file, values)
    CSV.open(file, 'a+') { |row| row << values }
  end

  # The directory where files are downloaded during test runs
  def self.download_dir
    File.join(ENV['HOME'], '/tmp/downloads')
  end

  # Prepares a directory to receive files downloaded during test runs
  # @param dir [File]
  def self.prepare_download_dir
    FileUtils::mkdir_p download_dir
    FileUtils.rm_rf(download_dir, secure: true)
  end

  # Creates users CSV for SIS import testing
  # @param users [Array<User>]
  # @return [File]
  def self.create_sis_user_import(users)
    logger.info 'Creating a user CSV for SIS import'
    csv = File.join(initialize_test_output_dir, 'users.csv')
    CSV.open(csv, 'wb') { |heading| heading << %w(user_id login_id first_name last_name email status) }
    users.each do |user|
      first_name = user.full_name.split(' ')[0]
      last_name = user.full_name.split(' ')[1]
      add_csv_row(csv, [user.sis_id, user.uid, first_name, last_name, user.email, user.status])
    end
    csv
  end

  # Creates enrollments CSV for SIS import testing
  # @param course [Course]
  # @param section [Section]
  # @param users [Array<User>]
  # @return [File]
  def self.create_sis_enrollment_import(course, section, users)
    logger.info 'Creating an enrollment CSV for SIS import'
    csv = File.join(initialize_test_output_dir, 'enrollments.csv')
    CSV.open(csv, 'wb') { |heading| heading << %w(course_id user_id role section_id status) }
    users.each do |user|
      logger.debug "UID #{user.uid} will be a #{user.role} in section #{section.sis_id} with status #{user.status}"
      add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
    end
    csv
  end

  # LOGGING

  # Returns the path and name of a logger file
  # @return [String]
  def self.log_file
    log_dir = File.join(ENV['HOME'], '/log/selenium-log')
    FileUtils.mkdir_p(log_dir) unless File.exist?(log_dir)
    File.join(log_dir, "#{Time.now.strftime('%Y-%m-%d')}.log")
  end

  # Logs an error message and its stacktrace
  # @param e [Exception]
  def self.log_error(e)
    logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
  end

  # The file to be used to write rake task test results
  # @param app_and_version [String] - e.g., 'junction-91' or 'suitec-2.2'
  def self.test_results(app_and_version)
    results_dir = File.join(ENV['HOME'], '/log/test-results')
    FileUtils.mkdir_p(results_dir) unless File.exist?(results_dir)
    File.join(results_dir, "test-results-#{app_and_version}-#{Time.now.strftime('%Y-%m-%d-%H-%M')}.log")
  end

  # TEST ACCOUNTS

  def self.super_admin_username
    @config['users']['super_admin_username']
  end

  def self.super_admin_password
    @config['users']['super_admin_password']
  end

  def self.super_admin_uid
    @config['users']['super_admin_uid']
  end

  def self.ets_qa_username
    @config['users']['ets_qa_username']
  end

  def self.ets_qa_password
    @config['users']['ets_qa_password']
  end

  def self.oski_uid
    @config['users']['oski_uid']
  end

  def self.test_user_password
    @config['users']['test_user_password']
  end

  # DATABASE

  # Queries a given database using a query string and returns the results
  # @param db_credentials [Hash]
  # @param query_string [String]
  # @return [PG::Result]
  def self.query_db(db_credentials, query_string)
    results = []
    begin
      connection = PG.connect(host: db_credentials[:host], port: db_credentials[:port], dbname: db_credentials[:name], user: db_credentials[:user], password: db_credentials[:password])
      logger.debug "Sending query '#{query_string}'"
      results = connection.exec query_string
    rescue PG::Error => e
      Utils.log_error e
    ensure
      connection.close if connection
      return results
    end
  end

  # Queries a database and returns the values in a given field
  # @param query_string [String]
  # @param field [String]
  # @return [String]
  def self.query_db_field(db_credentials, query_string, field)
    results = query_db(db_credentials, query_string)
    results.field_values(field)
  end

end
