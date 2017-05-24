require 'selenium-webdriver'
#miles testing

begin

  puts "#{Time.now} - Beginning OEC data source update script"
  args = ARGV.to_s
  campus_data_sources = %w(Campus_Courses Campus_Supervisors Campus_Instructors Campus_Students Campus_Course_Supervisors Campus_Course_Instructors Campus_Course_Students)
  extension_data_sources = Dir[File.join(ENV['HOME'], 'selenium-files/*.csv')] + Dir[File.join(ENV['HOME'], 'selenium-files/*.CSV')]
  @base_url = args.include?('qa') ? 'https://course-evaluations-qa.berkeley.edu' : 'https://course-evaluations.berkeley.edu'

  # Set timeouts and launch browser
  @brief_wait = Selenium::WebDriver::Wait.new(timeout: 30)
  @medium_wait = Selenium::WebDriver::Wait.new(timeout: 120)
  @long_wait = Selenium::WebDriver::Wait.new(timeout: 900)
  @driver = Selenium::WebDriver.for :chrome
  @driver.manage.window.maximize

  def click_element_id(driver, id)
    puts "#{Time.now} - Waiting for an element with ID '#{id}' to appear"
    @brief_wait.until { driver.find_element(id: id) }
    puts "#{Time.now} - Found the element, clicking it"
    driver.find_element(id: id).click
  end

  def log_in
    puts "#{Time.now} - Logging in to Blue at #{@base_url}"
    @driver.get "#{@base_url}"
    click_element_id(@driver, 'username')
    @long_wait.until { @driver.find_element(id: 'BlueAppControl_admin-link-btn') }
  end

  def find_and_edit_source(data_source)
    # Load homepage, click Admin button, and click Data Sources
    puts "#{Time.now} - Processing '#{data_source}'"
    @driver.get @base_url
    click_element_id(@driver, 'BlueAppControl_admin-link-btn')
    click_element_id(@driver, 'AdminUC_menu_item_data_sources')
    # Search for the data source type
    puts "#{Time.now} - Searching for data source"
    @brief_wait.until { @driver.find_element(id: 'AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing') }
    sleep 2
    @driver.find_element(id: 'AdminUC_DataSources_AdminDataSource_Tabs_tbSearchValue').send_keys data_source
    @driver.find_element(id: 'AdminUC_DataSources_AdminDataSource_Tabs_btnSearch').click
    @brief_wait.until { @driver.find_element(xpath: "//table[@id='AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing']//tr[3][contains(.,'#{data_source}')]") }
    @driver.find_element(link_text: 'Edit').click
    # Click Data tab and click Edit on Data Blocks tab
    puts "#{Time.now} - Found data source, editing it"
    click_element_id(@driver, 'AdminUC_Data_primary-tabs_Data')
    @brief_wait.until do
      @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_lblDataSource')
      @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_lblDataSource').text.include? data_source }
    end
    @driver.find_element(link_text: 'Edit').click
  end

  def upload_file(file)
    puts "#{Time.now} - Uploading file '#{file}'"
    @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_File1') }
    @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_File1').send_keys file
    sleep 2
    @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_btnUpload').click
    sleep 5
    @long_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_cbAll') }
  end

  def connect_source
    puts "#{Time.now} - Connecting data source"
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_btnUpload')
    sleep 2
    @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_cbAll') }
  end

  def apply_and_import_source
    # Apply data block update
    puts "#{Time.now} - Applying and importing data source"
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_cbAll')
    sleep 2
    @brief_wait.until do
      @driver.find_elements(xpath: '//table[@id="AdminUC_Data_ucAdminDS_Entities_FieldTable"]//input[@type="checkbox"]').each { |e| e.selected? }
    end
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_btnAdd')
    @long_wait.until { @driver.find_element(xpath: '//a[contains(.,"Data Block has been updated successfully.")]') }
    sleep 2
    # Import data source
    click_element_id(@driver, 'AdminUC_Data_primary-tabs_ImportExport')
    click_element_id(@driver, 'AdminUC_Data_AdminDS_Import_btnImport')
    @long_wait.until { @driver.find_element(id: 'AdminUC_Data_AdminDS_Import_btnConfirm') }
    click_element_id(@driver, 'AdminUC_Data_AdminDS_Import_btnConfirm')
    @long_wait.until { @driver.find_element(xpath: '//span[contains(.,"Data Import Approved and Successful")]') }
    @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_lnkBackToDataSources') }
    sleep 2
    puts "#{Time.now} - Import succeeded"
  end

  def create_results_file
    output_dir = File.join(ENV['HOME'], 'selenium-files')
    output_file = 'data_source_update_results.log'
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    file = File.join(output_dir, output_file)
    File.open(file, 'w') { |f| f.puts 'Results of OEC data source update script run:' }
    file
  end

  def log_results(file, result, e = nil)
    puts result
    puts "#{e.message}\n#{e.backtrace}" if e
    File.open(file, 'a') do |f|
      f.puts "\n => #{result}"
      f.puts "\n#{e.message}\n#{e.backtrace}" if e
    end
  end

  results_file = create_results_file
  if args.empty?

    log_results(results_file, "#{Time.now} - You didn't tell me what data sources to update. I quit.")

  else

    log_in

    # CAMPUS DATA SOURCES
    if args.include? 'campus'
      campus_data_sources.each do |data_source|
        begin
          find_and_edit_source data_source
          connect_source
          apply_and_import_source
          log_results(results_file, "#{Time.now} - Update succeeded for #{data_source}")
        rescue => e
          log_results(results_file, "#{Time.now} - Encountered an error with data source '#{data_source}'. Update failed.", e)
        end
      end
    end

    # EXTENSION DATA SOURCES
    if args.include? 'extension'
      if extension_data_sources.any?
        extension_data_sources.each do |file|
          begin
            find_and_edit_source (data_source = File.basename(file)[0..-5])
            upload_file file
            apply_and_import_source
            log_results(results_file, "#{Time.now} - Update succeeded for #{data_source}")
          rescue => e
            log_results(results_file, "#{Time.now} - Encountered an error with data source '#{data_source}'. Update failed.", e)
          end
        end
      else
        puts "#{Time.now} - There are no files to upload!"
        log_results(results_file, 'No files were uploaded for any data sources')
      end
    end
  end
rescue => e
  log_results(results_file, "#{Time.now} - Encountered an error initializing the script. No data sources were updated", e)
ensure
  @driver.quit
end