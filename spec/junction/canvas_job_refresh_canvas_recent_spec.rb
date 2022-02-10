unless ENV['STANDALONE']

  require_relative '../../util/spec_helper'

  # Prior to running, backdate last sync dates in Junction db to JunctionUtils.sis_update_date

  describe 'bCourses recent enrollment updates' do

    include Logging

    begin

      @driver = Utils.launch_browser
      @splash_page = Page::JunctionPages::SplashPage.new @driver
      @cal_net_page = Page::CalNetPage.new @driver
      @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
      @canvas_page = Page::CanvasPage.new @driver

      test_data = JunctionUtils.load_junction_test_course_data.select { |course| course['tests']['recent_update'] }
      roles = ['Teacher', 'Lead TA', 'TA', 'Student', 'Waitlist Student']
      @admin = User.new username: Utils.super_admin_username, canvas_id: Utils.super_admin_canvas_id
      sites_to_verify = []

      course_sites = test_data.map do |data|
        course = Course.new data
        course.sections.map! { |h| Section.new h }
        course.teachers.map! { |h| User.new h }
        {course: course, user_data: []}
      end

      logger.debug "There are #{course_sites.length} test courses"
      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)

      course_sites.each do |site|
        begin
          course = site[:course]
          @create_course_site_page.provision_course_site(course, @admin, course.sections, {admin: true})
          @canvas_page.set_course_sis_id course
          @canvas_page.set_section_sis_ids course
          @canvas_page.load_users_page course
          @canvas_page.wait_for_enrollment_import(course, roles)
          initial_users_with_sections = @canvas_page.get_users_with_sections course
          initial_enrollment_data = initial_users_with_sections.map do |u|
            {
                sid: u[:user].sis_id,
                section_id: u[:section].sis_id,
                role: u[:user].role
            }
          end
          site.merge!({enrollment: initial_enrollment_data})

          student_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'student' }
          waitlisted_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Waitlist Student' }
          ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'ta' }
          lead_ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Lead TA' }
          teacher_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'teacher' }

          csv = File.join(Utils.initialize_test_output_dir, "enrollments-#{course.code}.csv")
          CSV.open(csv, 'wb') { |heading| heading << %w(course_id user_id role section_id status) }

          students_to_delete = student_enrollments[0..9].map &:dup
          waitlists_to_delete = waitlisted_enrollments[0..9].map &:dup
          tas_to_delete = ta_enrollments[0..0].map &:dup
          lead_tas_to_delete = lead_ta_enrollments[0..1].map &:dup
          teachers_to_delete = teacher_enrollments[0..0].map &:dup
          students_to_convert = student_enrollments[10..19].map &:dup

          deletes = [students_to_delete + students_to_convert + waitlists_to_delete + tas_to_delete + lead_tas_to_delete + teachers_to_delete]
          deletes.flatten!
          logger.debug "#{deletes.map { |h| {sid: h[:user].sis_id, role: h[:user].role} }}"
          deletes.each { |h| h[:user].status = 'deleted' }
          deletes.each do |delete|
            user = delete[:user]
            section = delete[:section]
            Utils.add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
          end

          logger.debug "#{students_to_convert}"
          students_to_convert.each do |h|
            h[:user].role = 'Waitlist Student'
            h[:user].status = 'active'
          end
          students_to_convert.each do |converts|
            user = converts[:user]
            section = converts[:section]
            Utils.add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
          end

          # For one of the deletions, add a different user role manually to ensure that the manual role persists after an enrollment update
          if lead_tas_to_delete[0] && course.sections.length == 1
            teacher = lead_tas_to_delete[0].dup
            teacher[:user].role = 'Teacher'
            @canvas_page.add_users(course, [teacher[:user]])
            initial_enrollment_data << {sid: teacher[:user].sis_id, role: teacher[:user].role.downcase, section_id: teacher[:section].sis_id}
          end

          @canvas_page.upload_sis_imports([csv], [])
          sites_to_verify << site
        rescue => e
          Utils.log_error e
          it("hit an error in the test for #{site[:course].code}") { fail }
        end
      end

      @canvas_page.log_out @cal_net_page
      @canvas_page.load_homepage
      @cal_net_page.prompt_for_action 'RUN EXPORT AND REFRESH SCRIPTS MANUALLY'
      @cal_net_page.wait_for_manual_login

      #########################################
      ############  MANUAL STEPS  #############
      #########################################

      # 1. Run export_cached_csv_enrollments.sh
      # 2. Run refresh_canvas_recent.sh
      # 3. Log in manually to resume tests

      sites_to_verify.each do |site|
        course = site[:course]
        @canvas_page.load_course_site course
        updated_users_with_sections = @canvas_page.get_users_with_sections course
        updated_enrollment_data = updated_users_with_sections.map do |u|
          {
              sid: u[:user].sis_id,
              section_id: u[:section].sis_id,
              role: u[:user].role
          }
        end
        logger.debug "Original site membership: #{site[:enrollment]}"
        logger.debug "Updated site membership: #{updated_enrollment_data}"
        logger.debug "Current less original: #{updated_enrollment_data - site[:enrollment]}"
        logger.debug "Original less current: #{site[:enrollment] - updated_enrollment_data}"
        it("updates the enrollment for site ID #{site[:course].site_id} with no unexpected memberships") do
          expect(updated_enrollment_data - site[:enrollment]).to be_empty
        end
        it("updates the enrollment for site ID #{site[:course].site_id} with no missing memberships") do
          expect(site[:enrollment] - updated_enrollment_data).to be_empty
        end
      end
    end
  end
end
