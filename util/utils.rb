require 'hash_deep_merge'
require_relative 'spec_helper'

class Utils

  include Logging

  @config_dir = File.join(ENV['HOME'], '.webdriver-config/')

  # Initiate hash (before YAML load) to leverage 'hash_deep_merge' gem. The deep_merge support allows the YAML file in
  # your HOME directory to override a child property (e.g., 'timeouts.short') and yet hold on to sibling properties
  # (e.g., 'timeouts.long') in the default YAML. A standard Hash.merge would cause us to lose the entire parent
  # structure ('timeouts') in the default YAML.
  @config = {}
  @config.merge! YAML.load_file File.path('settings.yml')
  @config.deep_merge! YAML.load_file File.join(@config_dir, 'settings.yml')

  def self.config
    @config
  end

  def self.config_dir
    @config_dir
  end

  def self.assets_dir
    File.join(@config_dir, 'assets/')
  end

  # @param file_name [String]
  def self.asset_file_path(file_name)
    File.join(Utils.assets_dir, file_name)
  end

  def self.output_dir
    File.join(ENV['HOME'], 'webdriver-output/')
  end

  def self.logger_level
    const_get @config['logger_level']
  end

  # BROWSER CONFIGS

  # Instantiates the browser and alters default browser settings. If using Chrome and the 'chrome_profile' setting is true, an existing profile will
  # be used. A specific browser profile dir can be designated; otherwise, the default profile will be used. A use case for designating a non-default
  # profile is running two browser instances simultaneously to test WebSocket functionality, which cannot be done using the same profile. If the 'chrome_profile'
  # is false, a new profile will be used.
  # @param profile [String]
  # @return [Selenium::WebDriver]
  def self.launch_browser(profile = nil, driver = nil)
    driver_config = @config['webdriver']
    browser = driver || driver_config['browser']
    logger.info "Launching #{browser.capitalize}#{(' using profile at ' + profile) if profile}"

    # When launching browser, select the profile to use, tweak profile settings to facilitate file downloads, and launch in headless mode if desired.
    driver = case browser

      when 'chrome'
        options = Selenium::WebDriver::Chrome::Options.new
        if @config['webdriver']['chrome_profile']
          profile_dir = (profile ? profile : File.join(@config_dir, 'chrome-profile'))
          options.add_argument("user-data-dir=#{profile_dir}")
        end

        options.add_argument('--headless=new') if headless?
        options.add_preference('download.prompt_for_download', false)
        options.add_preference('download.default_directory', Utils.download_dir)
        options.add_preference('profile.default_content_setting_values.automatic_downloads', 1)
        Selenium::WebDriver.for :chrome, options: options

      when 'firefox'
        profile = Selenium::WebDriver::Firefox::Profile.new
        profile['browser.download.folderList'] = 2
        profile['browser.download.manager.showWhenStarting'] = false
        profile['browser.download.dir'] = Utils.download_dir
        profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/msword, application/vnd.ms-excel, application/vnd.ms-powerpointtd>, application/pdf, application/zip, audio/mpeg, image/png, image/bmp, image/jpeg, image/gif, image/sgi, image/svg+xml, image/webp, text/csv, video/mp4, video/quicktime'
        profile['browser.helperApps.alwaysAsk.force'] = false
        # Turn off Firefox's pretty JSON since it prevents parsing JSON strings in the browser.
        profile['devtools.jsonview.enabled'] = false
        profile['pdfjs.diabled'] = true
        options = Selenium::WebDriver::Firefox::Options.new
        options.profile = profile
        options.add_argument '-headless' if headless?
        Selenium::WebDriver.for :firefox, options: options

      else
        logger.error 'Designated WebDriver is not supported'
        nil
    end
    set_default_window_size driver
    driver.manage.timeouts.page_load = 120
    Selenium::WebDriver.logger.level = :error
    driver
  end

  def self.set_default_window_size(driver)
    headless? ? driver.manage.window.resize_to(1920, 1200) : driver.manage.window.maximize
  end

  def self.set_reduced_window_size(driver)
    driver.manage.window.resize_to(500, 700)
  end

  def self.use_optional_chrome_profile?
    @config['webdriver']['chrome_optional_profile']
  end

  def self.optional_chrome_profile_dir
    File.join(@config_dir, 'chrome-profile-optional')
  end

  def self.headless?
    case ENV['HEADLESS']
    when 'true'
      true
    when 'false'
      false
    else
      @config['webdriver']['headless']
    end
  end

  # @param driver [Selenium::WebDriver]
  def self.quit_browser(driver)
    logger.info 'Quitting the browser'

    # Before quitting, log any JS errors (or other console messages) encountered during the browser session
    log_js_errors driver
    driver.quit

  rescue NoMethodError

    # Pause after quitting the browser to make sure it shuts down completely before the next test relaunches it
    sleep 2
  end

  def self.get_js_errors(driver)
    js_log = driver.logs.get :browser
    js_log.map &:message
  end

  def self.log_js_errors(driver)
    if "#{driver.browser}" == 'chrome'
      messages = get_js_errors driver
      messages.each do |msg|
        unless msg.include?('chrome-search://thumb/') ||
          msg.include?('instructure.com') ||
          msg.include?('loadAllyCustomizations') ||
          msg.include?('cal1card-data/photos') ||
          msg.include?('prod.ally') ||
          msg.include?('cloudfront.net') ||
          msg.include?('Highcharts')
          logger.error "Possible JS error: #{msg}"
        end
      end
      return messages
    end
  end

  def self.console_error_present?(driver, error_string)
    js_log = driver.manage.logs.get(:browser)
    messages = js_log.map &:message
    messages.select { |msg| msg.include? error_string }.any?
  end

  # TIMEOUTS

  # How long to wait before clicking an element. Used to slow down or speed up test execution.
  def self.click_wait
    @config['timeouts']['click_wait']
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

  # Returns the number of seconds to wait for the poller to update appointment lists
  def self.boac_poller_wait
    @config['timeouts']['boac_poller']
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

  # The number of times to try loading additional rows on a Canvas course site roster
  def self.canvas_enrollment_retries
    @config['canvas']['enrollment_retries']
  end

  # TEST DATA, TEST RESULTS, UPLOADS

  # Returns the current datetime for use as a unique test identifier
  def self.get_test_id
    "QA Test #{Time.now.to_i}"
  end

  # Returns the name of the current spec's top level 'describe'. Used in the names of files generated by tests.
  # @param [RSpec::ExampleGroups]
  # @return [String]
  def self.get_test_script_name(spec)
    spec.inspect.sub('RSpec::ExampleGroups::', '')
  end

  # Makes sure a directory exists for files generated by tests
  # @return [String]
  def self.initialize_test_output_dir
    output_dir = File.join(self.output_dir, 'test-output')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    output_dir
  end

  # Creates a CSV in which test scripts can record information that is being presented in the UI
  # @param file_name [String]
  # @param headings [Array<String>]
  # @return [String]
  def self.create_test_output_csv(file_name, headings)
    file = File.join(Utils.initialize_test_output_dir, file_name)
    CSV.open(file, 'wb') { |csv| csv << headings }
    file
  end

  # Checks if a given (CSV) file exists. If not, creates the file using column headers.
  # @param file [File]
  # @param columns [Array<String>]
  # @return [File]
  def self.ensure_csv_exists(file, columns)
    unless File.exist? file
      logger.info "Initializing test output CSV named #{file}"
      CSV.open(file, 'wb') { |heading| heading << columns }
    end
    file
  end

  # Adds a row of data to a CSV
  # @param file [File]
  # @param values [Array<String>]
  def self.add_csv_row(file, values, columns = nil)
    ensure_csv_exists(file, columns)
    CSV.open(file, 'a+') { |row| row << values }
  end

  # The directory where files are downloaded during test runs
  def self.download_dir
    File.join(output_dir, 'downloads')
  end

  # Prepares a directory to receive files downloaded during test runs
  # @param dir [File]
  def self.prepare_download_dir
    FileUtils::mkdir_p download_dir
    FileUtils.rm_rf(download_dir, :secure => true)
  end

  def self.downloads_empty?
    !Dir.exist?(download_dir) || (Dir.entries(download_dir).reject { |f| %w(. ..).include? f }).empty?
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

  # @param course [Course]
  # @param users_with_sections [Array<Hash>]
  # @return [CSV]
  def self.create_sis_enrollment_import(course, users_with_sections)
    csv = File.join(initialize_test_output_dir, "enrollments-#{course.code}.csv")
    CSV.open(csv, 'wb') { |heading| heading << %w(course_id user_id role section_id status) }
    users_with_sections.each do |user_with_section|
      user = user_with_section[:user]
      section = user_with_section[:section]
      add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
    end
    csv
  end

  # Creates enrollments CSV for SIS import testing
  # @param course [Course]
  # @param section [Section]
  # @param users [Array<User>]
  # @return [File]
  def self.create_sis_section_enrollment_import(course, section, users)
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
    log_dir = File.join(output_dir, 'selenium-log')
    FileUtils.mkdir_p(log_dir) unless File.exist?(log_dir)
    File.join(log_dir, "#{Time.now.strftime('%Y-%m-%d')}.log")
  end

  # Logs an error message and its stacktrace
  # @param e [Exception]
  def self.log_error(e, msg=nil)
    logger.error msg if msg
    logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
  end

  # The file to be used to write rake task test results
  # @param app_and_version [String] - e.g., 'junction-91' or 'suitec-2.2'
  def self.test_results(app_and_version)
    results_dir = File.join(output_dir, 'test-results')
    FileUtils.mkdir_p(results_dir) unless File.exist?(results_dir)
    File.join(results_dir, "test-results-#{app_and_version}.log")
  end

  # TEST ACCOUNTS

  def self.super_admin_username
    (ENV['USER'] && !ENV['USER'].empty?) ? ENV['USER'] : @config['users']['super_admin_username']
  end

  def self.super_admin_password
    (ENV['PASS'] && !ENV['PASS'].empty?) ? ENV['PASS'] : @config['users']['super_admin_password']
  end

  def self.super_admin_uid
    @config['users']['super_admin_uid']
  end

  def self.super_admin_canvas_id
    @config['users']['super_admin_canvas_id']
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

  def self.gmail_password
    @config['users']['gmail_password']
  end

  # DATABASE

  # Queries a Postgres database using a query string and returns the results
  # @param db_credentials [Hash]
  # @param query_string [String]
  # @return [PG::Result]
  def self.query_pg_db(db_credentials, query_string)
    begin
      creds = {
          host: db_credentials[:host],
          port: db_credentials[:port],
          dbname: db_credentials[:name],
          user: db_credentials[:user],
          password: db_credentials[:password]
      }
      connection = PG.connect creds
      logger.debug "Sending query '#{query_string}'"
      start = Time.now
      results = connection.exec query_string
      logger.info "Query took #{Time.now - start} seconds"
      results
    rescue PG::Error => e
      Utils.log_error e
      fail
    ensure
      connection.close if connection
    end
  end

  # Queries a Postgres database and returns the values in a given field
  # @param query_string [String]
  # @param field [String]
  # @return [String]
  def self.query_pg_db_field(db_credentials, query_string, field)
    results = query_pg_db(db_credentials, query_string)
    results.field_values(field)
  end

  def self.in_op(arr)
    arr.map {|i| "'#{i}'"}.join(', ')
  end

  # Converts term name to the SIS code for the term
  # @param term_name [String]
  # @return [String]
  def self.term_name_to_sis_code(term_name)
    split = term_name.split
    year_code = split[1][0] + split[1][2..3]
    season_code = case split[0]
                    when 'Spring'
                      '2'
                    when 'Summer'
                      '5'
                    when 'Fall'
                      '8'
                    else
                      logger.error "Unknown term season '#{split[0]}'"
                      fail
                  end
    year_code + season_code
  end

  def self.sis_code_to_term_name(term_id)
    term_id = term_id.to_s
    season = case term_id[-1]
                  when '2'
                    'Spring'
                  when '5'
                    'Summer'
                  when '8'
                    'Fall'
                  else
                    logger.error "Unknown term season code '#{term_id[-1]}'"
                    fail
                  end
    "#{season} #{term_id[0]}0#{term_id[1..2]}"
  end

  def self.next_term_sis_id(term_id)
    d1 = '2'
    d2_3 = (term_id[-1] == '8' ? (term_id[1..2].to_i + 1).to_s : term_id[1..2])
    d4 = case term_id[3]
         when '2'
           '5'
         when '5'
           '8'
         else
           '2'
         end
    "#{d1}#{d2_3}#{d4}"
  end

  def self.previous_term_code(term_id)
    d1 = '2'
    d2_3 = (term_id[-1] == '2') ? (term_id[1..2].to_i - 1).to_s : term_id[1..2]
    d4 = case term_id[3]
         when '8'
           '5'
         when '5'
           '2'
         else
           '8'
         end
    "#{d1}#{d2_3}#{d4}"
  end

  def self.term_name_to_hyphenated_code(term_name)
    parts = term_name.split
    semester = case parts[0]
               when 'Spring'
                 'B'
               when 'Summer'
                 'C'
               else
                 'D'
               end
    "#{parts[1]}-#{semester}"
  end

  def self.term_code_to_term_name(term_code)
    parts = term_code.split('-')
    season = case parts[1]
             when 'B'
               'Spring'
             when 'C'
               'Summer'
             else
               'Fall'
             end
    "#{season} #{parts[0]}"
  end

  # SCREENSHOTS

  def self.save_screenshot(driver, unique_id)
    output_dir = File.join(self.output_dir, 'screenshots')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    logger.info "Saving screenshot named '#{unique_id}.png'"
    driver.save_screenshot File.join(output_dir, "#{unique_id}.png")
  end

  # FORMATTING

  def self.int_to_s_with_commas(int)
    int.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse
  end

end
