require_relative '../../util/spec_helper'

if (ENV['NO_DEPS'] || ENV['NO_DEPS'].nil?) && !ENV['DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test = BOACTestConfig.new
      test.navigation
      pages_tested = []
      bubbles_tested = []

      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @class_list_page = BOACClassListViewPage.new @driver
      @class_matrix_page = BOACClassMatrixViewPage.new @driver
      @student_page = BOACStudentPage.new @driver
      @homepage.dev_auth test.advisor

      test.test_students.each do |student|
        begin

          api_user_page = BOACApiStudentPage.new @driver
          api_user_page.get_data(@driver, student)

          terms = api_user_page.terms
          if terms.any?
            @student_page.load_page student
            logger.debug "There are #{terms.length} terms"
            logger.debug "The first term is #{api_user_page.term_name terms.first}"

            term = terms.first
            begin

              term_name = api_user_page.term_name term
              term_id = api_user_page.term_id term
              @student_page.expand_academic_year term_name
              logger.info "Checking term #{term_name}"

              courses = api_user_page.courses term
              courses.each do |course|
                begin

                  course_sis_data = api_user_page.sis_course_data course
                  logger.info "Checking course #{course_sis_data[:code]}"
                  sections = api_user_page.sections course
                  sections.each do |section|
                    begin

                      section_data = api_user_page.sis_section_data section
                      api_section_page = BOACApiSectionPage.new @driver
                      api_section_page.get_data(@driver, term_id, section_data[:ccn])
                      class_test_case = "UID #{student.uid} term #{term_name} course #{course_sis_data[:code]} section #{section_data[:component]} #{section_data[:number]} #{section_data[:ccn]}"
                      logger.info "Checking #{class_test_case}"

                      @student_page.load_page student
                      @student_page.expand_academic_year term_name
                      if @student_page.class_page_link(term_id, section_data[:ccn]).exists? && !pages_tested.include?("#{term_id} #{section_data[:ccn]}")
                        @student_page.click_class_page_link(term_id, section_data[:ccn])
                        pages_tested << "#{term_id} #{section_data[:ccn]}"

                        # CLASS PAGE - List View

                        visible_sids = @class_list_page.visible_sids.sort.uniq
                        expected_sids = api_section_page.student_sids.sort
                        it("shows all the expected list view students in #{class_test_case}") { expect(visible_sids).to eql(expected_sids) }

                        # Visit student
                        @class_list_page.click_student_link BOACUser.new({:uid => @class_list_page.list_view_uids.last})
                        list_to_student = @student_page.verify_block { @student_page.sid_element.when_visible Utils.short_wait }
                        it("links student pages from the list view of #{class_test_case}") { expect(list_to_student).to be true }

                        # Back to list view
                        @driver.navigate.back
                        student_to_list = @class_list_page.verify_block { @class_list_page.wait_until(Utils.short_wait) { @class_list_page.course_title == course_sis_data[:title] } }
                        it("returns to the list view of #{class_test_case}") { expect(student_to_list).to be true }

                        # CLASS PAGE - Matrix View

                        if @class_matrix_page.matrix_view_button?

                          @class_list_page.click_matrix_view
                          @class_matrix_page.wait_for_matrix
                          student_expanded = @class_matrix_page.bubble_expanded? student
                          if api_user_page.sis_profile_data[:cumulative_gpa]
                            it("shows the student's bubble expanded in #{class_test_case}") { expect(student_expanded).to be true }
                          else
                            it("does not show the student's bubble expanded in #{class_test_case}") { expect(student_expanded).to be false }
                          end

                          all_students_present = @class_matrix_page.verify_all_students_present expected_sids.length
                          it("shows all the expected matrix view students in #{class_test_case}") { expect(all_students_present).to be true }

                          # Visit student. Clicking a matrix bubble will throw an error if another bubble obscures it, so only proceed if the bubble is clickable.
                          student_page_testable = if @class_matrix_page.matrix_bubbles.any?
                                                    begin
                                                      @class_matrix_page.click_last_student_bubble
                                                      bubbles_tested << class_test_case
                                                      true
                                                    rescue => e
                                                      logger.error "#{e.message}"
                                                      false
                                                    end
                                                  else
                                                    @class_matrix_page.click_last_no_data_student
                                                    true
                                                  end

                          if student_page_testable
                            matrix_to_student = @student_page.verify_block { @student_page.sid_element.when_visible Utils.short_wait }
                            it("links student pages from the matrix view of #{class_test_case}") { expect(matrix_to_student).to be true }

                          else
                            logger.warn "Skipping matrix to student page tests because the bubbles are all bunched up for #{class_test_case}"
                          end
                        else
                          logger.warn "Skipping matrix view testing since there is no matrix view for #{class_test_case}"
                        end
                      end
                    rescue => e
                      BOACUtils.log_error e
                      it("caused an error with UID #{student.uid} #{class_test_case}") { fail }
                    end
                  end
                rescue => e
                  BOACUtils.log_error e
                  it("caused an error with UID #{student.uid} term #{term_id} course #{course_sis_data[:code]}") { fail }
                end
              end
            rescue => e
              BOACUtils.log_error e
              it("caused an error with UID #{student.uid} term #{term_id}") { fail }
            end
          end
        rescue => e
          BOACUtils.log_error e
          it("caused an error with UID #{student.uid}") { fail }
        end
      end

    rescue => e
      BOACUtils.log_error e
      it('has at least one testable matrix bubble') { expect(bubbles_tested).not_to be_empty }
      it('threw an error') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end
