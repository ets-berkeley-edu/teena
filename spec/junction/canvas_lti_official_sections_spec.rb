require_relative '../../util/spec_helper'

describe 'bCourses Official Sections tool' do

  standalone = ENV['STANDALONE']

  include Logging

  test = JunctionTestConfig.new
  test.official_sections

  begin

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @official_sections_page = Page::JunctionPages::CanvasCourseManageSectionsPage.new @driver

    sites = []
    sites_to_create = []

    # COLLECT SIS DATA FOR ALL TEST COURSES

    test.courses.each do |course|

      begin
        sections = test.set_course_sections course

        test_course = {
            course: course,
            teacher: test.set_sis_teacher(course),
            sections: sections,
            sections_for_site: sections.select(&:include_in_site),
            site_abbreviation: nil,
            academic_data: ApiAcademicsCourseProvisionPage.new(@driver)
        }

        @splash_page.load_page
        @splash_page.basic_auth(test_course[:teacher].uid, @cal_net)
        test_course[:academic_data].get_feed @driver
        sites_to_create << test_course

      rescue => e
        it("encountered an error retrieving SIS data for #{test_course[:course].code}") { fail }
        Utils.log_error e
      ensure
        @splash_page.load_page
        @splash_page.log_out
      end
    end

    unless standalone
      @canvas.load_homepage
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    end

    # Create course sites that don't already exist
    sites_to_create.each do |site|
      standalone ? @splash_page.basic_auth(site[:teacher].uid) : @canvas.masquerade_as(site[:teacher])
      logger.debug "Sections to be included at site creation are #{site[:sections_for_site].map { |s| s.id }}"
      @create_course_site_page.provision_course_site(site[:course], site[:teacher], site[:sections_for_site], {standalone: standalone})
      @create_course_site_page.wait_for_standalone_site_id(site[:course], site[:teacher], @splash_page) if standalone
      sites << site
      @create_course_site_page.log_out if standalone
    end

    # ADD AND REMOVE SECTIONS FOR ALL TEST COURSES

    sites.each do |site|

      begin
        logger.info "Test course is #{site[:course].code}"
        sections_to_add_delete = (site[:sections] - site[:sections_for_site])
        section_ids_to_add_delete = (sections_to_add_delete.map { |section| section.id }).join(', ')
        logger.debug "Sections to be added and deleted are #{section_ids_to_add_delete}"

        if standalone
          @splash_page.basic_auth site[:teacher].uid
          @official_sections_page.load_standalone_tool site[:course]
        else
          @canvas.masquerade_as site[:teacher]
          @canvas.publish_course_site site[:course]
          @official_sections_page.load_embedded_tool site[:course]
        end

        # STATIC VIEW - sections currently in the site

        @official_sections_page.current_sections_table.when_visible Utils.medium_wait

        static_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{site[:course].site_id}") { expect(static_view_sections_count).to eql(site[:sections_for_site].length) }

        site[:sections_for_site].each do |section|
          ui_course_code = @official_sections_page.current_section_course section
          ui_section_label = @official_sections_page.current_section_label section
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows the course code for section #{section.id}") { expect(ui_course_code).to eql(section.course) }
          it("shows the section label for section #{section.id}") { expect(ui_section_label).to eql(section.label) }
          it("shows no Delete button for section #{section.id}") { expect(has_delete_button).to be false }
        end

        # EDITING VIEW - NOTICES AND LINKS

        @official_sections_page.click_edit_sections
        logger.debug "There are #{@official_sections_page.available_sections_count(site[:course])} rows in the available sections table"

        has_maintenance_notice = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button_element.when_present Utils.short_wait
          @official_sections_page.maintenance_detail_element.when_not_visible 1
        end

        has_maintenance_detail = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button
          @official_sections_page.maintenance_detail_element.when_visible Utils.short_wait
        end

        has_bcourses_service_link = @official_sections_page.external_link_valid?(@official_sections_page.bcourses_service_link_element, 'bCourses | Digital Learning Services')
        @official_sections_page.switch_to_canvas_iframe unless standalone || @driver.browser.to_s == 'firefox'

        it("shows a collapsed maintenance notice on course site ID #{site[:course].site_id}") { expect(has_maintenance_notice).to be true }
        it("allows the user to reveal an expanded maintenance notice #{site[:course].site_id}") { expect(has_maintenance_detail).to be true }
        it("offers a link to the bCourses service page in the expanded maintenance notice #{site[:course].site_id}") { expect(has_bcourses_service_link).to be true }

        # EDITING VIEW - ALL COURSE SECTIONS CURRENTLY IN A COURSE SITE

        edit_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{site[:course].site_id}") { expect(edit_view_sections_count).to eql(site[:sections_for_site].length) }

        site[:sections_for_site].each do |section|
          has_section_in_site = @official_sections_page.current_section_id_element(section).exists?
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows section #{section.id} is already in course site #{site[:course].site_id}") { expect(has_section_in_site).to be true }
          it("shows a Delete button for section #{section.id}") { expect(has_delete_button).to be true }
        end

        # EDITING VIEW - THE RIGHT TEST COURSE SECTIONS ARE AVAILABLE TO ADD TO THE COURSE SITE

        is_expanded = @official_sections_page.available_sections_table(site[:course].code).exists?
        available_section_count = @official_sections_page.available_sections_count(site[:course])
        save_button_enabled = @official_sections_page.save_changes_button_element.enabled?

        it("shows an expanded view of courses with sections already in course site ID #{site[:course].site_id}") { expect(is_expanded).to be true }
        it("shows all the sections in the course #{site[:course].code}") { expect(available_section_count).to eql(site[:sections].length) }
        it("shows a disabled save button when no changes have been made in course site ID #{site[:course].site_id}") { expect(save_button_enabled).to be false }

        site[:sections].each do |section|
          has_section_available = @official_sections_page.available_section_id_element(site[:course].code, section.id).exists?
          has_add_button = @official_sections_page.section_add_button(site[:course], section).exists?

          it("shows section #{section.id} is available for course site #{site[:course].site_id}") { expect(has_section_available).to be true }
          it "shows an Add button for section #{section.id}" do
            (site[:sections_for_site].include? section) ?
                (expect(has_add_button).to be false) :
                (expect(has_add_button).to be true)
          end
        end

        # EDITING VIEW - THE RIGHT DATA IS DISPLAYED FOR ALL AVAILABLE SEMESTER COURSES

        semester_name = site[:course].term
        semester = site[:academic_data].all_teaching_semesters.find { |semester| site[:academic_data].semester_name(semester) == semester_name }
        semester_courses = site[:academic_data].semester_courses semester

        semester_courses.each do |course_data|
          api_course_code = site[:academic_data].course_code course_data
          api_course_title = site[:academic_data].course_title course_data

          ui_sections_expanded = @official_sections_page.expand_available_sections api_course_code
          ui_course_title = @official_sections_page.available_sections_course_title api_course_code

          it("shows the right course title for #{api_course_code}") { expect(ui_course_title).to eql(api_course_title) }
          it("shows no blank course title for #{api_course_code}") { expect(ui_course_title.empty?).to be false }
          it("allows the user to to expand the available sections for #{api_course_code}") { expect(ui_sections_expanded).to be_truthy }

          # Check each section
          site[:academic_data].course_sections(course_data).each do |section_data|
            api_section_data = site[:academic_data].section_data section_data
            logger.debug "Checking data for section ID #{api_section_data[:id]}"
            ui_section_data = @official_sections_page.available_section_data(api_course_code, api_section_data[:id])

            it("shows the right course code for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:code]).to eql(api_section_data[:code]) }
            it("shows no blank course code for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:code].empty?).to be false }
            it("shows the right section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label]).to eql(api_section_data[:label]) }
            it("shows no blank section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label].empty?).to be false }
            it("shows the right section schedules for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:schedules]).to eql(api_section_data[:schedules]) }
            it("shows the right section locations for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:locations]).to eql(api_section_data[:locations]) }

            it "shows an expected instruction mode for #{api_course_code} section #{api_section_data[:id]}" do
              mode = ui_section_data[:label].split('(').last.gsub(')', '')
              expect(['In Person', 'Online', 'Hybrid', 'Flexible', 'Remote']).to include(mode)
            end
          end

          ui_sections_collapsed = @official_sections_page.collapse_available_sections api_course_code
          it("allows the user to collapse the available sections for #{api_course_code}") { expect(ui_sections_collapsed).to be_truthy }
        end

        # STAGING OR UN-STAGING SECTIONS FOR ADDING OR DELETING

        @official_sections_page.expand_available_sections site[:course].code

        sections_to_add_delete.last do |section|

          logger.debug 'Testing add and undo add'
          @official_sections_page.click_add_section(site[:course], section)
          section_staged_for_add = @official_sections_page.current_section_id_element(section).exists?
          section_add_button_gone = !@official_sections_page.section_add_button(site[:course], section).exists?
          section_added_msg = @official_sections_page.section_added_element(site[:course], section).exists?

          it("'add' button moves section #{section.id} from available to current sections") { expect(section_staged_for_add).to be true }
          it("hides the add button for section #{section.id} when staged for adding") { expect(section_add_button_gone).to be true }
          it("shows an 'added' message for section #{section.id} when staged for adding") { expect(section_added_msg).to be true }

          @official_sections_page.click_undo_add_section section
          section_unstaged_for_add = !@official_sections_page.current_section_id_element(section).exists?
          section_add_button_back = @official_sections_page.section_add_button(site[:course], section).exists?

          it("'undo add' button removes section #{section.id} from current sections") { expect(section_unstaged_for_add).to be true }
          it("reveals the add button for section #{section.id} when un-staged for adding") { expect(section_add_button_back).to be true }
        end

        site[:sections_for_site].first do |section|

          logger.debug 'Testing delete and undo delete'
          @official_sections_page.click_delete_section section
          section_staged_for_delete = !@official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button = @official_sections_page.section_undo_delete_button(site[:course], section).exists?

          it("'delete' button removes section #{section.id} from current sections") { expect(section_staged_for_delete).to be true }
          it("reveals the 'undo delete' button for section #{section.id} when staged for deleting") { expect(section_undo_delete_button).to be true }

          @official_sections_page.click_undo_delete_section(site[:course], section)
          section_unstaged_for_delete = @official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button_gone = !@official_sections_page.section_undo_delete_button(site[:course], section).exists?
          section_still_available = @official_sections_page.available_section_id_element(site[:course], section).exists?

          it("allows the user to un-stage section #{section.id} for deleting from course site ID #{site[:course].site_id}") { expect(section_unstaged_for_delete).to be true }
          it("hides the 'undo delete' button for section #{section.id} when un-staged for deleting") { expect(section_undo_delete_button_gone).to be true }
          it("still shows section #{section.id} among available sections when un-staged for deleting") { expect(section_still_available).to be true }
        end

        # ADDING SECTIONS

        standalone ? @official_sections_page.load_standalone_tool(site[:course]) : @official_sections_page.load_embedded_tool(site[:course])
        @official_sections_page.click_edit_sections
        @official_sections_page.add_sections(site[:course], sections_to_add_delete)

        added_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.medium_wait
        added_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        add_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_with_adds = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{site[:course].site_id}") { expect(added_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(added_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(add_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(total_sections_with_adds).to eql(site[:sections].length) }

        sections_to_add_delete.each do |section|
          section_added = @official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{site[:course].site_id}") { expect(section_added).to be true }
        end

        # Check that sections present on Find a Person to Add tool are updated immediately
        standalone ? @course_add_user_page.load_standalone_tool(site[:course]) : @course_add_user_page.load_embedded_tool(site[:course])
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
        ttl_user_sections_with_adds = @course_add_user_page.verify_block do
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == site[:sections].length }
        end
        it("shows the right number of current sections on Find a Person to Add when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(ttl_user_sections_with_adds).to be true }

        # Check that the site enrollment is updated with section members
        unless standalone
          enrollments_added = @canvas.verify_block do
            tries = 5
            begin
              tries -= 1
              sleep Utils.short_wait
              @canvas.load_users_page site[:course]
              @canvas.load_all_students site[:course]
              visible_sections = @canvas.section_label_elements.map(&:text).uniq
              added_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
              @canvas.wait_until(1) { (visible_sections & added_sections).any? }
            rescue
              tries.zero? ? fail : retry
            end
          end
          it("adds the sections #{section_ids_to_add_delete} to the site #{site[:course].site_id}") { expect(enrollments_added).to be true }
        end

        # DELETING SECTIONS

        standalone ? @official_sections_page.load_standalone_tool(site[:course]) : @official_sections_page.load_embedded_tool(site[:course])
        @official_sections_page.click_edit_sections
        @official_sections_page.delete_sections sections_to_add_delete

        deleted_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.short_wait
        deleted_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        delete_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_without_deletes = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{site[:course].site_id}") { expect(deleted_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(deleted_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(delete_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(total_sections_without_deletes).to eql(site[:sections_for_site].length) }

        sections_to_add_delete.each do |section|
          section_deleted = !@official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{site[:course].site_id}") { expect(section_deleted).to be true }
        end

        # Check that sections present on Find a Person to Add tool are updated immediately
        standalone ? @course_add_user_page.load_standalone_tool(site[:course]) : @course_add_user_page.load_embedded_tool(site[:course])
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
        ttl_user_sections_with_deletes = @course_add_user_page.verify_block do
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == site[:sections_for_site].length }
        end
        it("shows the right number of current sections on Find a Person to Add when sections #{section_ids_to_add_delete} have been removed from course site #{site[:course].site_id}") { expect(ttl_user_sections_with_deletes).to be true }

        # Check that the site enrollment is updated
        unless standalone
          enrollments_deleted = @canvas.verify_block do
            tries = Utils.short_wait
            begin
              tries -= 1
              sleep Utils.short_wait
              @canvas.load_users_page site[:course]
              @canvas.load_all_students site[:course]
              visible_sections = @canvas.section_label_elements.map(&:text).uniq
              deleted_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
              @canvas.wait_until(1) { (visible_sections & deleted_sections).empty? }
            rescue
              tries.zero? ? fail : retry
            end
          end
          it("removes the sections #{section_ids_to_add_delete} from the site #{site[:course].site_id}") { expect(enrollments_deleted).to be true }
        end

        # CHECK USER ROLE ACCESS TO THE TOOL FOR ONE COURSE

        if site == sites.last && !standalone

          @canvas.stop_masquerading

          user_roles = [test.lead_ta, test.ta, test.designer, test.reader, test.observer, test.students.first, test.wait_list_student]
          user_roles.each do |user|
            @course_add_user_page.load_embedded_tool site[:course]
            @course_add_user_page.search(user.uid, 'CalNet UID')
            @course_add_user_page.add_user_by_uid(user, site[:sections_for_site].first)
          end

          # Check each user role's access to the tool

          lead_ta_perms = @official_sections_page.verify_block do
            @canvas.masquerade_as(test.lead_ta, site[:course])
            @official_sections_page.load_embedded_tool site[:course]
            @official_sections_page.current_sections_table.when_visible Utils.medium_wait
            @official_sections_page.edit_sections_button_element.when_visible 1
          end
          it("allows #{test.lead_ta.role} #{test.lead_ta.uid} full access to the tool") { expect(lead_ta_perms).to be true }

          [test.ta, test.designer].each do |user|
            has_full_perms = @official_sections_page.verify_block do
              @canvas.masquerade_as(user, site[:course])
              @official_sections_page.load_embedded_tool site[:course]
              @official_sections_page.current_sections_table.when_visible Utils.medium_wait
              @official_sections_page.edit_sections_button_element.when_not_visible 1
            end
            it("allows #{user.role} #{user.uid} read only access to the tool") { expect(has_full_perms).to be true }
          end

          reader_perms = @official_sections_page.verify_block do
            @canvas.masquerade_as(test.reader, site[:course])
            @official_sections_page.load_embedded_tool site[:course]
            @official_sections_page.unexpected_error_element.when_present Utils.medium_wait
            @official_sections_page.current_sections_table.when_not_visible 1
          end
          it("denies #{test.reader.role} #{test.reader.uid} access to the tool") { expect(reader_perms).to be true }

          [test.observer, test.students.first, test.wait_list_student].each do |user|
            has_no_perms = @canvas.verify_block do
              @canvas.masquerade_as(user, site[:course])
              @official_sections_page.hit_embedded_tool_url site[:course]
              @canvas.wait_for_error(@canvas.access_denied_msg_element, @official_sections_page.unexpected_error_element)
            end
            it("denies #{user.role} #{user.uid} access to the tool") { expect(has_no_perms).to be true }
          end
        end

      rescue => e
        it("encountered an error for #{site[:course].code}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      ensure
        @splash_page.log_out if standalone
      end
    end

    # SECTION NAME UPDATES

    unless standalone
      site = sites.first
      section = (site[:sections] - site[:sections_for_site]).first
      @canvas.stop_masquerading

      # Create and upload SIS import with a fake section name
      @canvas.set_course_sis_id site[:course]
      section_id = "SEC:#{JunctionUtils.term_code}-#{section.id}"
      section_name = "#{site[:course].code} FAKE LABEL"
      csv = File.join(Utils.initialize_test_output_dir, "section-#{site[:course].code}.csv")
      CSV.open(csv, 'wb') { |heading| heading << %w(section_id course_id name status start_date end_date) }
      Utils.add_csv_row(csv, [section_id, site[:course].sis_id, section_name, 'active', nil, nil ])
      @canvas.upload_sis_imports([csv], [])
      JunctionUtils.clear_cache(@driver, @splash_page)

      # Verify the tool warns of section name mismatch
      @canvas.masquerade_as site[:teacher]
      @official_sections_page.load_embedded_tool site[:course]
      @official_sections_page.current_sections_table.when_visible Utils.long_wait
      @official_sections_page.click_edit_sections
      update_msg_present = @official_sections_page.section_name_msg_element.when_visible(Utils.short_wait)
      it "shows a section name mismatch message for section #{section.id} on course site #{site[:course].site_id}" do
        expect(update_msg_present).to be_truthy
      end

      # Update the section and verify the tool no longer complains of mismatch
      @official_sections_page.click_update_section section
      @official_sections_page.save_changes_and_wait_for_success
      @official_sections_page.click_edit_sections
      update_msg_still_present = @official_sections_page.section_name_msg?
      it "shows no section name mismatch message for updated section #{section.id} on course site #{site[:course].site_id}" do
        expect(update_msg_still_present).to be false
      end
    end

  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
