require_relative 'spec_helper'

class JunctionUtils < Utils

  include Logging

  @config = Utils.config['junction']

  # JUNCTION

  # Base URL of Junction test environment
  def self.junction_base_url
    @config['base_url']
  end

  # The suffix to append to an email address local-part when testing mailing lists
  def self.mailing_list_suffix
    junction_base_url.include?('-qa') ? '-cc-ets-qa' : '-cc-ets-dev'
  end

  # Basic auth password for CalCentral test environments
  def self.junction_basic_auth_password
    @config['basic_auth_password']
  end

  def self.junction_oec_user_uid
    @config['oec_uid']
  end

  def self.junction_test_data_file
    File.join(Utils.config_dir, 'test-data-bcourses.json')
  end

  # Loads file containing test data for course-driven bCourses tests
  def self.load_junction_test_data
    JSON.parse File.read(junction_test_data_file)
  end

  # Loads test data for course-driven bCourses tests
  def self.load_junction_test_course_data
    load_junction_test_data['courses']
  end

  # Loads test data for user-driven bCourses tests
  def self.load_junction_test_user_data
    load_junction_test_data['users']
  end

  # The number of times to poll for completed site creation when testing background tasks
  def self.background_job_attempts
    @config['background_job_attempts']
  end

  def self.term_name
    @config['term_name']
  end

  def self.term_code
    @config['term']
  end

  # The number of times to multiply the test data when testing background tasks
  def self.background_job_multiplier
    @config['background_job_multiplier']
  end

  def self.sis_update_date
    Time.parse @config['sis_update_date']
  end

  # Sets the site id for a course in the test data for course-driven bCourses tests
  # @param course [Course]
  def self.set_junction_test_course_id(course)
    logger.info "Updating Junction test data with course site ID #{course.site_id} for #{course.term} #{course.code}"
    parsed = load_junction_test_data
    course_test_data = parsed['courses'].find { |data| data['code'] == course.code && data['term'] == course.term }
    course_test_data['site_id'] = course.site_id
    course_test_data['site_created_date'] = Date.today.to_s

    Dir.glob("#{Utils.config_dir}/test-data-bcourses.json").each { |f| File.delete f }
    File.open(junction_test_data_file, 'w') { |f| f.write JSON.pretty_generate(parsed) }
  end

  # Authenticates in Junction as an admin and expires all cache
  # @param driver [Selenium::WebDriver]
  # @param splash_page [Page::JunctionPages::SplashPage]
  def self.clear_cache(driver, splash_page)
    splash_page.load_page
    begin
      splash_page.log_out
    rescue
      splash_page.load_page
    end
    splash_page.basic_auth @config['admin_uid']
    driver.get("#{junction_base_url}/api/cache/clear")
    sleep 3
    splash_page.load_page
    splash_page.log_out
  end

  # Creates CSV for data generated during Junction test runs
  # @param spec [RSpec::ExampleGroups]
  # @param column_headers [Array]
  # @return [File]
  def self.initialize_junction_test_output(spec, column_headers)
    output_file = "#{Utils.get_test_script_name spec}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(Utils.initialize_test_output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << column_headers }
    test_output
  end

  # Canvas ID of create course site tool
  def self.canvas_create_site_tool
    Utils.config['canvas']['create_site_tool']
  end

  # Canvas ID of course add user tool
  def self.canvas_course_add_user_tool
    Utils.config['canvas']['course_add_user_tool']
  end

  # Canvas ID of course captures tool
  def self.canvas_course_captures_tool
    Utils.config['canvas']['course_captures_tool']
  end

  # Canvas ID of course official sections tool
  def self.canvas_official_sections_tool
    Utils.config['canvas']['official_sections_tool']
  end

  # Canvas ID of admin mailing lists tool
  def self.canvas_mailing_lists_tool
    Utils.config['canvas']['mailing_lists_tool']
  end

  # Canvas ID of instructor mailing list tool
  def self.canvas_mailing_list_tool
    Utils.config['canvas']['mailing_list_tool']
  end

  # Canvas ID of e-grades export tool
  def self.canvas_e_grades_export_tool
    Utils.config['canvas']['e_grades_export_tool']
  end

  def self.user_prov_tool
    Utils.config['canvas']['user_prov_tool']
  end

  def self.db_credentials
    {
      host: @config['db_host'],
      port: @config['db_port'],
      name: @config['db_name'],
      user: @config['db_user'],
      password: @config['db_password']
    }
  end

  def self.drop_existing_mailing_lists
    sql_1 = 'DELETE FROM canvas_site_mailing_lists'
    sql_2 = 'DELETE FROM canvas_site_mailing_list_members'
    Utils.query_pg_db(db_credentials, sql_1)
    Utils.query_pg_db(db_credentials, sql_2)
  end

end
