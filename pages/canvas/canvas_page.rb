require_relative '../../util/spec_helper'

module Page

  class CanvasPage

    include PageObject
    include Logging
    include Page
    include CanvasPeoplePage

    h2(:updated_terms_heading, xpath: '//h2[contains(text(),"Updated Terms of Use")]')
    checkbox(:terms_cbx, name: 'user[terms_of_use]')
    button(:accept_course_invite, name: 'accept')
    link(:masquerade_link, xpath: '//a[contains(@href, "masquerade")]')
    link(:stop_masquerading_link, class: 'stop_masquerading')
    h2(:recent_activity_heading, xpath: '//h2[contains(text(),"Recent Activity")]')
    h3(:project_site_heading, xpath: '//h3[text()="Is bCourses Right For My Project?"]')

    link(:about_link, text: 'About')
    link(:accessibility_link, text: 'Accessibility')
    link(:nondiscrimination_link, text: 'Nondiscrimination')
    link(:privacy_policy_link, text: 'Privacy Policy')
    link(:terms_of_service_link, text: 'Terms of Service')
    link(:data_use_link, text: 'Data Use & Analytics')
    link(:honor_code_link, text: 'UC Berkeley Honor Code')
    link(:student_resources_link, text: 'Student Resources')
    link(:user_prov_link, text: 'User Provisioning')
    link(:conf_tool_link, text: 'BigBlueButton (Conferences)')

    button(:submit_button, xpath: '//button[contains(.,"Submit")]')
    button(:save_button, xpath: '//button[text()="Save"]')
    button(:update_course_button, xpath: '//button[contains(.,"Update Course Details")]')
    li(:update_course_success, xpath: '//*[contains(.,"successfully updated")]')
    form(:profile_form, xpath: '//form[@action="/logout"]')
    link(:profile_link, id: 'global_nav_profile_link')
    button(:logout_link, xpath: '//button[contains(.,"Logout")]')
    link(:policies_link, id: 'global_nav_academic_policies_link')

    h1(:unexpected_error_msg, xpath: '//h1[contains(text(),"Unexpected Error")]')
    h2(:unauthorized_msg, xpath: '//h2[contains(text(),"Unauthorized")]')
    h1(:access_denied_msg, xpath: '//h1[text()="Access Denied"]')
    div(:flash_msg, xpath: '//div[@class="flashalert-message"]')

    # Loads the Canvas homepage, optionally using a non-default Canvas base URL
    # @param canvas_base_url [String]
    def load_homepage(canvas_base_url = nil)
      logger.debug "Canvas base url is #{canvas_base_url}" if canvas_base_url
      canvas_base_url ? navigate_to(canvas_base_url) : navigate_to("#{Utils.canvas_base_url}")
    end

    # Loads the Canvas homepage and logs in to CalNet, optionally using a non-default Canvas base URL
    # @param cal_net [Page::CalNetPage]
    # @param username [String]
    # @param password [String]
    # @param canvas_base_url [String]
    def log_in(cal_net, username, password, canvas_base_url = nil)
      load_homepage canvas_base_url
      cal_net.log_in(username, password)
    end

    # Shifts to default content, logs out, and waits for CalNet logout confirmation
    # @param driver [Selenium::WebDriver]
    # @param cal_net [Page::CalNetPage]
    # @param event [Event]
    def log_out(driver, cal_net, event = nil)
      driver.switch_to.default_content
      wait_for_update_and_click_js profile_link_element
      sleep 1
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click_js logout_link_element if logout_link_element.exists?
      cal_net.username_element.when_visible Utils.short_wait
      add_event(event, EventType::LOGGED_OUT)
    end

    # Masquerades as a user and then loads a course site
    # @param user [User]
    # @param course [Course]
    def masquerade_as(user, course = nil)
      load_homepage
      sleep 2
      stop_masquerading if stop_masquerading_link?
      logger.info "Masquerading as #{user.role} UID #{user.uid}, Canvas ID #{user.canvas_id}"
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}/masquerade"
      wait_for_update_and_click masquerade_link_element
      stop_masquerading_link_element.when_visible Utils.short_wait
      load_course_site course unless course.nil?
    end

    # Quits masquerading as another user
    def stop_masquerading
      logger.debug 'Ending masquerade'
      load_homepage
      wait_for_load_and_click stop_masquerading_link_element
      stop_masquerading_link_element.when_not_visible(Utils.medium_wait) rescue Selenium::WebDriver::Error::StaleElementReferenceError
    end

    # Loads a given sub-account page
    def load_sub_account(sub_account)
      logger.debug "Loading sub-account #{sub_account}"
      navigate_to "#{Utils.canvas_base_url}/accounts/#{sub_account}"
    end

    def click_user_prov
      logger.info 'Clicking the link to the User Provisioning tool'
      wait_for_load_and_click user_prov_link_element
      switch_to_canvas_iframe
    end

    # Clicks the 'save and publish' button using JavaScript rather than WebDriver
    def click_save_and_publish
      scroll_to_bottom
      wait_for_update_and_click_js save_and_publish_button_element
    end

    def wait_for_flash_msg(text, wait)
      flash_msg_element.when_visible wait
      wait_until(1) { flash_msg.include? text }
    end

    # COURSE SITE SETUP

    link(:create_site_link, xpath: '//a[contains(text(),"Create a Site")]')
    link(:create_site_settings_link, xpath: '//div[contains(@class, "profile-tray")]//a[contains(text(),"Create a Site")]')

    button(:add_new_course_button, xpath: '//button[@aria-label="Create new course"]')
    text_area(:course_name_input, xpath: '(//form[@aria-label="Add a New Course"]//input)[1]')
    text_area(:ref_code_input, xpath: '(//form[@aria-label="Add a New Course"]//input)[2]')
    select_list(:term, id: 'course_enrollment_term_id')
    button(:create_course_button, xpath: '//button[contains(.,"Add Course")]')

    span(:course_site_heading, xpath: '//li[contains(@id,"crumb_course_")]//span')
    text_area(:search_course_input, xpath: '//input[@placeholder="Search courses..."]')
    button(:search_course_button, xpath: '//input[@id="course_name"]/following-sibling::button')
    paragraph(:add_course_success, xpath: '//p[contains(.,"successfully added!")]')

    link(:course_details_link, text: 'Course Details')
    text_area(:course_title, id: 'course_name')
    text_area(:course_code, id: 'course_course_code')

    button(:delete_course_button, xpath: '//button[text()="Delete Course"]')
    li(:delete_course_success, xpath: '//li[contains(.,"successfully deleted")]')

    def click_create_site_settings_link
      wait_for_update_and_click_js profile_link_element
      sleep 1
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click create_site_settings_link_element
      switch_to_canvas_iframe
    end

    def create_squiggy_course(test)
      if test.course.site_id.nil?
        logger.info "Creating a Squiggy course site named #{test.course.title}"
        load_sub_account Utils.canvas_qa_sub_account
        wait_for_load_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        wait_for_element_and_type(course_name_input_element, "#{test.course.title}")
        wait_for_element_and_type(ref_code_input_element, "#{test.course.code}")
        wait_for_update_and_click create_course_button_element
        add_course_success_element.when_visible Utils.medium_wait
        test.course.site_id = search_for_course(test.course, Utils.canvas_qa_sub_account)
      else
        navigate_to "#{Utils.canvas_base_url}/courses/#{test.course.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        test.course.title = course_title
        test.course.code = course_code
      end
      logger.info "Course site ID is #{test.course.site_id}"
      publish_course_site test.course
      add_users(test.course, test.course.roster)
      add_squiggy_tools test
    end

    # Creates standard Canvas course site in a given sub-account, publishes it, and adds test users.
    # @param sub_account [String]
    # @param course [Course]
    # @param test_users [Array<User>]
    # @param test_id [String]
    # @param tools [Array<LtiTools>]
    # @param event [Event]
    def create_generic_course_site(sub_account, course, test_users, test_id, tools = nil, event = nil)
      if course.site_id.nil?
        load_sub_account sub_account
        wait_for_load_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        course.title = "QA Test - #{Time.at test_id.to_i}" if course.title.nil?
        course.code = "QA #{Time.at test_id.to_i} LEC001" if course.code.nil?
        wait_for_element_and_type(course_name_input_element, "#{course.title}")
        wait_for_element_and_type(ref_code_input_element, "#{course.code}")
        logger.info "Creating a course site named #{course.title} in #{course.term} semester"
        wait_for_update_and_click create_course_button_element
        add_course_success_element.when_visible Utils.medium_wait
        course.site_id = search_for_course(course, sub_account)
        unless course.term.nil?
          navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
          wait_for_element_and_select_js(term_element, course.term)
          wait_for_update_and_click_js update_course_button_element
          update_course_success_element.when_visible Utils.medium_wait
        end
      else
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        course.title = course_title
        course.code = course_code
      end
      publish_course_site course
      logger.info "Course ID is #{course.site_id}"
      add_users(course, test_users, event)
      if tools
        tools.each do |tool|
          unless tool_nav_link(tool).exists?
            add_suite_c_tool(course, tool) if [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS, LtiTools::IMPACT_STUDIO].include? tool
          end
          disable_tool(course, tool) unless tools.include? tool
        end
      end
    end

    # Clicks the 'create a site' button for the Junction LTI tool. If the click fails, the button could be behind a footer.
    # Retries after hiding the footer.
    # @param driver [Selenium::WebDriver]
    def click_create_site(driver)
      tries ||= 2
      wait_for_load_and_click create_site_link_element
    rescue
      execute_script('arguments[0].style.hidden="hidden";', div_element(id: 'fixed_bottom'))
      retry unless (tries -= 1).zero?
    ensure
      switch_to_canvas_iframe JunctionUtils.junction_base_url
    end

    # Loads a course site and handles prompts that can appear
    # @param course [Course]
    def load_course_site(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}"
      wait_until(Utils.medium_wait) { current_url.include? "#{course.site_id}" }
      if updated_terms_heading?
        logger.info 'Accepting terms and conditions'
        terms_cbx_element.when_visible Utils.short_wait
        check_terms_cbx
        submit_button
      end
      div_element(id: 'content').when_present Utils.medium_wait
      sleep 1
      if accept_course_invite?
        logger.info 'Accepting course invite'
        accept_course_invite
        accept_course_invite_element.when_not_visible Utils.medium_wait
      end
    end

    # Searches a sub-account for a course site using a unique identifier
    # @param course [Course]
    # @param sub_account [String]
    # @return [String]
    def search_for_course(course, sub_account)
      tries ||= 6
      logger.info "Searching for '#{course.title}'"
      load_sub_account sub_account
      wait_for_element_and_type(search_course_input_element, "#{course.title}")
      sleep 1
      wait_for_update_and_click link_element(text: "#{course.title}")
      wait_until(Utils.short_wait) { course_site_heading.include? "#{course.code}" }
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
    rescue
      logger.error('Course site not found, retrying')
      sleep Utils.short_wait
      (tries -= 1).zero? ? fail : retry
    end

    link(:course_details_tab, xpath: '//a[contains(.,"Course Details")]')
    text_area(:course_sis_id, id: 'course_sis_source_id')
    link(:sections_tab, xpath: '//a[contains(@href,"#tab-sections")]')
    elements(:section_data, :span, xpath: '//li[@class="section"]/span[@class="users_count"]')
    text_area(:section_name, id: 'course_section_name')
    button(:add_section_button, xpath: '//button[@title="Add Section"]')
    link(:edit_section_link, class: 'edit_section_link')
    text_area(:section_sis_id, id: 'course_section_sis_source_id')
    button(:update_section_button, xpath: '//button[contains(.,"Update Section")]')

    # Obtains the Canvas SIS ID for the course site
    # @param course [Course]
    # @return [String]
    def set_course_sis_id(course)
      load_course_settings course
      course_sis_id_element.when_visible Utils.short_wait
      course.sis_id = course_sis_id_element.attribute('value')
      logger.debug "Course SIS ID is #{course.sis_id}"
      course.sis_id
    end

    # Obtains the Canvas SIS IDs for the sections on the course site
    # @param course [Course]
    def set_section_sis_ids(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings#tab-sections"
      wait_for_load_and_click sections_tab_element
      wait_until(Utils.short_wait) { section_data_elements.any? }
      sis_ids = section_data_elements.map do |el|
        el.when_visible(Utils.short_wait)
        el.text.split[-2]
      end
      course.sections.each do |section|
        section.sis_id = sis_ids.find { |id| id.include? section.id }
      end
    end

    # Adds a section to a course site and assigns SIS IDs to both the course and the section
    # @param course [Course]
    # @param section [Section]
    def add_sis_section_and_ids(course, section)
      # Add SIS id to course
      load_course_settings course
      wait_for_load_and_click course_details_tab_element
      wait_for_element_and_type(course_sis_id_element, course.sis_id)
      wait_for_update_and_click update_course_button_element
      update_course_success_element.when_visible Utils.short_wait
      # Add unique section
      wait_for_update_and_click_js sections_tab_element
      wait_for_element_and_type(section_name_element, section.sis_id)
      wait_for_update_and_click add_section_button_element
      # Add SIS id to section
      wait_for_update_and_click link_element(text: section.sis_id)
      wait_for_update_and_click edit_section_link_element
      wait_for_element_and_type(section_sis_id_element, section.sis_id)
      wait_for_update_and_click update_section_button_element
      update_section_button_element.when_not_visible Utils.short_wait
    end

    div(:publish_div, id: 'course_status_actions')
    button(:publish_button, class: 'btn-publish')
    button(:save_and_publish_button, class: 'save_and_publish')
    button(:published_button, class: 'btn-published')
    form(:published_status, id: 'course_status_form')
    radio_button(:activity_stream_radio, xpath: '//span[contains(.,"Course Activity Stream")]/ancestor::label')
    button(:choose_and_publish_button, xpath: '//span[contains(.,"Choose and Publish")]/ancestor::button')

    # Publishes a course site
    # @param course [Course]
    def publish_course_site(course)
      logger.info 'Publishing the course'
      load_course_site course
      published_status_element.when_visible Utils.short_wait
      if published_button?
        logger.debug 'The site is already published'
      else
        logger.debug 'The site is unpublished, publishing'
        wait_for_update_and_click publish_button_element
        unless course.create_site_workflow
          wait_for_update_and_click activity_stream_radio_element
          wait_for_update_and_click choose_and_publish_button_element
        end
        published_button_element.when_present Utils.medium_wait
      end
    end

    # Edits the course site title
    # @param course [Course]
    def edit_course_name(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_element_and_type(text_area_element(id: 'course_name'), course.title)
      wait_for_update_and_click button_element(xpath: '//button[contains(.,"Update Course Details")]')
      list_item_element(xpath: '//li[contains(.,"Course was successfully updated")]').when_present Utils.short_wait
    end

    # Deletes a course site
    # @param driver [Selenium::WebDriver]
    # @param course [Course]
    def delete_course(driver, course)
      load_homepage
      stop_masquerading if stop_masquerading_link?
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/confirm_action?event=delete"
      wait_for_load_and_click_js delete_course_button_element
      delete_course_success_element.when_visible Utils.medium_wait
      logger.info "Course id #{course.site_id} has been deleted"
    end

    # SIS IMPORTS

    text_area(:file_input, name: 'attachment')
    button(:upload_button, xpath: '//button[contains(.,"Process Data")]')
    div(:import_success_msg, xpath: '//div[contains(.,"The import is complete and all records were successfully imported.")]')

    # Uploads CSVs on the SIS Import page
    # @param files [Array<String>]
    # @param users [Array<User>]
    # @param event [Event]
    def upload_sis_imports(files, users, event = nil)
      files.each do |csv|
        logger.info "Uploading a SIS import CSV at #{csv}"
        navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_uc_berkeley_sub_account}/sis_import"
        file_input_element.when_visible Utils.short_wait
        file_input_element.send_keys csv
        wait_for_update_and_click upload_button_element
        import_success_msg_element.when_present Utils.long_wait
      end
      users.each do |u|
        (u.status == 'active') ?
            add_event(event, EventType::CREATE, u.full_name) :
            add_event(event, EventType::MODIFY, u.full_name)
      end
    end

    # SETTINGS

    checkbox(:set_grading_scheme_cbx, id: 'course_grading_standard_enabled')

    # Loads the course settings page
    # @param course [Course]
    def load_course_settings(course)
      logger.info "Loading settings page for course ID #{course.site_id}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings#tab-details"
      set_grading_scheme_cbx_element.when_present Utils.medium_wait
    end

    # LTI TOOLS

    link(:apps_link, text: 'Apps')
    link(:navigation_link, text: 'Navigation')
    link(:view_apps_link, text: 'View App Configurations')
    link(:add_app_link, class: 'add_tool_link')
    select_list(:config_type, id: 'configuration_type_selector')
    text_area(:app_name_input, xpath: '//input[@placeholder="Name"]')
    text_area(:key_input, xpath: '//input[@placeholder="Consumer Key"]')
    text_area(:secret_input, xpath: '//input[@placeholder="Shared Secret"]')
    text_area(:url_input, xpath: '//input[@placeholder="Config URL"]')

    # Returns the link element for the configured LTI tool on the course site sidebar
    # @param tool [LtiTools]
    # @return [PageObject::Elements::Link]
    def tool_nav_link(tool)
      link_element(xpath: "//ul[@id='section-tabs']//a[text()='#{tool.name}']")
    end

    # Loads the LTI tool configuration page for a course site
    # @param course [Course]
    def load_tools_config_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings/configurations"
    end

    # Loads the site navigation page
    # @param course [Course]
    def load_navigation_page(course)
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer_and_popup
    end

    # Enables an LTI tool that is already installed
    # @param course [Course]
    # @param tool [LtiTools]
    def enable_tool(course, tool)
      load_navigation_page course
      wait_for_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a")
      wait_for_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Enable this item']")
      list_item_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
      save_button
      tool_nav_link(tool).when_visible Utils.medium_wait
    end

    # Disables an LTI tool that is already installed
    # @param course [Course]
    # @param tool [LtiTools]
    def disable_tool(course, tool)
      logger.info "Disabling #{tool.name}"
      load_navigation_page course
      if verify_block { link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
        logger.debug "#{tool.name} is already installed but disabled, skipping"
      else
        if link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
          logger.debug "#{tool.name} is installed and enabled, disabling"
          wait_for_update_and_click link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a")
          wait_for_update_and_click link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Disable this item']")
          list_item_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
          save_button
          tool_nav_link(tool).when_not_visible Utils.medium_wait
          pause_for_poller
        else
          logger.debug "#{tool.name} is not installed, skipping"
        end
      end
    end

    # Adds an LTI tool to a course site. If the tool is installed and enabled, skips it. If the tool is installed by disabled, enables
    # it. Otherwise, installs and enables it.
    # @param course [Course]
    # @param tool [LtiTools]
    # @param base_url [String]
    def add_lti_tool(course, tool, base_url, credentials)
      logger.info "Adding and/or enabling #{tool.name}"
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer_and_popup
      if verify_block { link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
        logger.debug "#{tool.name} is already installed and enabled, skipping"
      else
        if link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
          logger.debug "#{tool.name} is already installed but disabled, enabling"
          enable_tool(course, tool)
          pause_for_poller
        else
          logger.debug "#{tool.name} is not installed, installing and enabling"
          wait_for_update_and_click apps_link_element
          wait_for_update_and_click add_app_link_element

          # Enter the tool config
          config_type_element.when_visible Utils.short_wait
          wait_for_element_and_select_js(config_type_element, 'By URL')
          # Use JS to select the option too since the WebDriver method is not working consistently
          execute_script('document.getElementById("configuration_type_selector").value = "url";')
          sleep 1
          wait_for_update_and_click_js app_name_input_element
          wait_for_element_and_type(app_name_input_element, "#{tool.name}")
          wait_for_element_and_type(key_input_element, credentials[:key])
          wait_for_element_and_type(secret_input_element, credentials[:secret])
          wait_for_element_and_type(url_input_element, "#{base_url}#{tool.xml}")
          submit_button
          link_element(xpath: "//td[@title='#{tool.name}']").when_present Utils.medium_wait
          enable_tool(course, tool)
        end
      end
    end

    # Adds a SuiteC LTI tool to a course site
    # @param course [Course]
    # @param tool [LtiTools]
    def add_suite_c_tool(course, tool)
      add_lti_tool(course, tool, SuiteCUtils.suite_c_base_url, SuiteCUtils.lti_credentials)
    end

    def add_squiggy_tools(test)
      creds = SquiggyUtils.lti_credentials
      test.course.lti_tools.each do |tool|
        logger.info "Adding and/or enabling #{tool.name}"
        load_tools_config_page test.course
        wait_for_update_and_click navigation_link_element
        hide_canvas_footer_and_popup
        if verify_block { link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
          logger.debug "#{tool.name} is already installed and enabled, skipping"
        else
          if link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
            logger.debug "#{tool.name} is already installed but disabled, enabling"
            enable_tool(test.course, tool)
            pause_for_poller
          else
            logger.debug "#{tool.name} is not installed, installing and enabling"
            wait_for_update_and_click apps_link_element
            wait_for_update_and_click add_app_link_element
            wait_for_element_and_select_js(config_type_element, 'By URL')
            execute_script('document.getElementById("configuration_type_selector").value = "url";')
            sleep 1
            wait_for_update_and_click_js app_name_input_element
            wait_for_element_and_type(app_name_input_element, "#{tool.name}")
            wait_for_element_and_type(key_input_element, creds[:key])
            wait_for_element_and_type(secret_input_element, creds[:secret])
            wait_for_element_and_type(url_input_element, "#{SquiggyUtils.base_url}#{tool.xml}")
            submit_button
            link_element(xpath: "//td[@title='#{tool.name}']").when_present Utils.medium_wait
            enable_tool(test.course, tool)
          end
        end
      end
      test.course.engagement_index_url = click_tool_link SquiggyTool::ENGAGEMENT_INDEX
      test.course.asset_library_url = click_tool_link SquiggyTool::ASSET_LIBRARY
      asset_library = SquiggyAssetLibraryListViewPage.new @driver
      canvas_assigns_page = CanvasAssignmentsPage.new @driver
      switch_to_canvas_iframe
      asset_library.ensure_canvas_sync(test, canvas_assigns_page)
    end

    # Clicks the navigation link for a tool and returns the tool's URL. Optionally records an analytics event.
    # @param tool [LtiTools]
    # @param event [Event]
    # @return [String]
    def click_tool_link(tool, event = nil)
      switch_to_main_content
      hide_canvas_footer_and_popup
      wait_for_update_and_click_js tool_nav_link(tool)
      wait_until(Utils.medium_wait) { title == "#{tool.name}" }
      logger.info "#{tool.name} URL is #{url = current_url}"
      add_event(event, EventType::NAVIGATE)
      add_event(event, EventType::VIEW)
      url.delete '#'
    end

    checkbox(:hide_grade_distrib_cbx, id: 'course_hide_distribution_graphs')

    # Returns whether or not the 'Hide grade distribution graphs from students' option is selected on a course site
    # @param course [Course]
    # @return [boolean]
    def grade_distribution_hidden?(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_load_and_click link_element(text: 'more options')
      hide_grade_distrib_cbx_element.when_visible Utils.short_wait
      hide_grade_distrib_cbx_checked?
    end

    # MESSAGES

    text_area(:message_addressee, name: 'recipients[]')
    text_area(:message_input, name: 'body')

    # FILES

    link(:files_link, text: 'Files')
    button(:access_toggle, xpath: '//button[@aria-label="Notice to Instructors for Making Course Materials Accessible"]')
    link(:access_basics_link, xpath: '//a[contains(., "Accessibility Basics for bCourses")]')
    link(:access_checker_link, xpath: '//a[contains(., "How do I use the Accessibility Checker")]')
    link(:access_dsp_link, xpath: '//a[contains(., "How to improve the accessibility of your online content")]')
    link(:access_sensus_link, xpath: '//a[contains(., "SensusAccess Conversion")]')
    link(:access_ally_link, xpath: '//a[contains(., "Ally in bCourses Service Page")]')

    def click_files_tab
      logger.info 'Clicking Files tab'
      wait_for_update_and_click files_link_element
    end

    def toggle_access_links
      wait_for_update_and_click access_toggle_element
    end

  end
end
