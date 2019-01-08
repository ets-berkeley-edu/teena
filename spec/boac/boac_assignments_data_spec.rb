require_relative '../../util/spec_helper'

describe 'BOAC assignment analytics' do

  include Logging

  begin

    if Utils.headless?

      logger.warn 'This script requires admin Canvas access and cannot be run headless. Terminating.'

    else

      test = BOACTestConfig.new
      test.assignments NessieUtils.get_all_students

      user_analytics_data_heading = %w(UID Sport Term SiteCode SiteId
                                        AssignMin AssignMax AssignUser AssignPerc AssignRound
                                        GradesMin GradesMax GradesUser GradesPerc GradesRound)
      user_course_analytics_data = Utils.create_test_output_csv('boac-canvas-courses.csv', user_analytics_data_heading)

      user_course_assigns_heading = %w(UID CanvasID Site AssignmentID URL DueDate Submission SubmitDate Type OnTime)
      user_course_assigns = Utils.create_test_output_csv('boac-assignments.csv', user_course_assigns_heading)

      @driver = Utils.launch_browser test.chrome_profile
      @cal_net = Page::CalNetPage.new @driver
      @canvas_assignments_page = Page::CanvasAssignmentsPage.new @driver
      @canvas_discussions_page = Page::CanvasAnnounceDiscussPage.new @driver
      @canvas_grades_page = Page::CanvasGradesPage.new @driver
      @canvas_users_page = Page::CanvasPage.new @driver
      @e_grades_page = Page::JunctionPages::CanvasEGradesExportPage.new @driver
      @boac_homepage = BOACHomePage.new @driver
      @boac_student_page = BOACStudentPage.new @driver
      @boac_homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)

      test.max_cohort_members.each do |student|

        boac_api_page = BOACApiUserAnalyticsPage.new @driver
        boac_api_page.get_data(@driver, student)
        boac_api_page.set_canvas_id student
        term = boac_api_page.terms.find { |t| boac_api_page.term_name(t) == test.term }

        if term
          begin

            # Collect all the Canvas sites in the term, matched and unmatched
            term_sites = []
            term_sites << boac_api_page.unmatched_sites(term).map { |s| {:data => s} }

            courses = boac_api_page.courses term
            if courses.any?
              courses.each do |course|
                course_sites = boac_api_page.course_sites course
                term_sites << course_sites.map { |s| {:data => s, :index => course_sites.index(s)} }
              end
            end

            term_sites.flatten.each do |site|
              begin

                site_data = site[:data]
                site_code = boac_api_page.site_metadata(site_data)[:code]
                site_id = boac_api_page.site_metadata(site_data)[:site_id]
                course = Course.new({:site_id => site_id})
                test_case = "Canvas ID #{student.canvas_id} UID #{student.uid} term #{test.term} course site ID #{site_id}, #{site_code}"

                logger.info "Checking site #{site_id}, #{site_code}"

                # Gather the analytics data obtained from Nessie
                boac_api_assigns_submitted = boac_api_page.nessie_assigns_submitted site_data
                boac_api_grades = boac_api_page.nessie_grades site_data

                if BOACUtils.nessie_assignments

                  logger.warn "Checking assignment submissions for #{test_case}"

                  # Un-mute all assignments so that scores are visible to the student
                  @canvas_assignments_page.load_course_site(@driver, course)
                  @canvas_assignments_page.stop_masquerading(@driver) if @canvas_assignments_page.stop_masquerading_link?
                  @e_grades_page.resolve_all_issues(@driver, course)
                  @canvas_assignments_page.masquerade_as(@driver, student)
                  ui_assignments = @canvas_assignments_page.get_assignments(@driver, course, student, @canvas_discussions_page)
                  nessie_assignments = NessieUtils.get_assignments(student, course)

                  if ui_assignments.any?
                    # Compare the individual assignment data in Nessie with the same assignments in the Canvas UI
                    it("has the right assignments for #{test_case}") { expect(ui_assignments.map(&:id).sort).to eql(nessie_assignments.map(&:id).sort) }
                    ui_assignments.each do |ui|
                      Utils.add_csv_row(user_course_assigns, [student.uid, student.canvas_id, site_id, ui.id, ui.url, ui.due_date, ui.submitted, ui.submission_date, ui.type, ui.on_time])
                      nessie_assign = nessie_assignments.find { |n| n.id == ui.id }
                      it("has the right assignment submission status for assignment ID #{ui.id} #{test_case}") { expect(nessie_assign.submitted).to eql(ui.submitted) }
                    end

                    # Compare the total submitted assignment count in the BOAC API with the same assignment count in the Canvas UI
                    submitted = ui_assignments.select &:submitted
                    it("has the right Nessie assignments-submitted count for #{test_case}") { expect(boac_api_assigns_submitted[:score].to_i).to eql(submitted.length) }
                  else
                    logger.warn 'Either there are no assignments, or they are from a past semester and have been hidden in the UI.'
                  end

                else
                  logger.warn 'Skipping comparison of assignment submissions in Nessie versus Canvas UI'
                end

                if BOACUtils.nessie_scores

                  if boac_api_grades[:score].empty?

                    logger.warn "Skipping current score tests for #{test_case}"

                  else

                    logger.warn "Checking current score for #{test_case}"

                    @canvas_grades_page.stop_masquerading(@driver) if @canvas_grades_page.stop_masquerading_link?
                    @canvas_grades_page.load_gradebook course
                    scores = @canvas_grades_page.export_grades course

                    gradebook_min = scores.first
                    logger.debug "Gradebook minimum current score: #{gradebook_min}"
                    gradebook_min = gradebook_min[:score]
                    it("has the same Canvas Gradebook and Nessie grades minimum for #{test_case}") { expect((gradebook_min.to_i - 1)..(gradebook_min.to_i + 1)).to include(boac_api_grades[:min].to_i) }

                    gradebook_max = scores.last
                    logger.debug "Gradebook maximum current score: #{gradebook_max}"
                    gradebook_max = gradebook_max[:score]
                    it("has the same Canvas Gradebook and Nessie grades maximum for #{test_case}") { expect((gradebook_max.to_i - 1)..(gradebook_max.to_i + 1)).to include(boac_api_grades[:max].to_i) }

                    gradebook_user_score = (scores.find { |s| s[:uid] == student.uid })[:score]
                    it("has the same Canvas Gradebook and Nessie grades user score for #{test_case}") { expect((gradebook_user_score.to_i - 1)..(gradebook_user_score.to_i + 1)).to include(boac_api_grades[:score].to_i) }
                  end

                else
                  logger.warn 'Skipping comparison of current scores in Nessie versus Canvas UI'
                end

                if BOACUtils.tooltips

                  @boac_student_page.load_page student
                  @boac_student_page.click_view_previous_semesters if test.term != BOACUtils.term

                  # Find the site in the UI differently if it's matched versus unmatched
                  site_code ?
                      (analytics_xpath = @boac_student_page.course_site_xpath(test.term, site_code, site[:index])) :
                      (analytics_xpath = @boac_student_page.unmatched_site_xpath(test.term, site_code))

                  [boac_api_assigns_submitted, boac_api_grades].each do |analytics|

                    if analytics[:perc_round].nil?
                      no_data = @boac_student_page.no_data?(analytics_xpath, analytics[:type])
                      it("shows no '#{analytics[:type]}' data for #{test_case}") { expect(no_data).to be true }
                    else
                      visible_analytics = case analytics[:type]
                                            when 'Assignments Submitted'
                                              @boac_student_page.visible_assignment_analytics(@driver, analytics_xpath, analytics)
                                            when 'Assignment Grades'
                                              @boac_student_page.visible_grades_analytics(@driver, analytics_xpath, analytics)
                                            else
                                              logger.error "Unsupported analytics type '#{analytics[:type]}'"
                                          end

                      it("shows the '#{analytics[:type]}' user percentile for #{test_case}") { expect(visible_analytics[:perc_round]).to eql(analytics[:perc_round]) }
                      it("shows the '#{analytics[:type]}' user score for #{test_case}") { expect(visible_analytics[:score]).to eql(analytics[:score]) }
                      it("shows the '#{analytics[:type]}' course maximum for #{test_case}") { expect(visible_analytics[:max]).to eql(analytics[:max]) }

                      if analytics[:graphable]
                        it("shows the '#{analytics[:type]}' course 70th percentile for #{test_case}") { expect(visible_analytics[:perc_70]).to eql(analytics[:perc_70]) }
                        it("shows the '#{analytics[:type]}' course 50th percentile for #{test_case}") { expect(visible_analytics[:perc_50]).to eql(analytics[:perc_50]) }
                        it("shows the '#{analytics[:type]}' course 30th percentile for #{test_case}") { expect(visible_analytics[:perc_30]).to eql(analytics[:perc_30]) }
                        it("shows the '#{analytics[:type]}' course minimum for #{test_case}") { expect(visible_analytics[:minimum]).to eql(analytics[:minimum]) }
                      else
                        it("shows no '#{analytics[:type]}' course 70th percentile for #{test_case}") { expect(visible_analytics[:perc_70]).to be_nil }
                        it("shows no '#{analytics[:type]}' course 50th percentile for #{test_case}") { expect(visible_analytics[:perc_50]).to be_nil }
                        it("shows no '#{analytics[:type]}' course 30th percentile for #{test_case}") { expect(visible_analytics[:perc_30]).to be_nil }
                        it("shows no '#{analytics[:type]}' course minimum for #{test_case}") { expect(visible_analytics[:minimum]).to be_nil }
                      end
                    end
                  end
                end

              rescue => e
                Utils.log_error e
                it("encountered an error with UID #{student.uid} #{test_case}") { fail }
              ensure
                row = [student.uid, student.sports, test.term, site_code, site_id, boac_api_assigns_submitted[:min], boac_api_assigns_submitted[:max],
                       boac_api_assigns_submitted[:score], boac_api_assigns_submitted[:perc], boac_api_assigns_submitted[:perc_round],
                       boac_api_grades[:min], boac_api_grades[:max], boac_api_grades[:score], boac_api_grades[:perc], boac_api_grades[:perc_round]
                ]
                Utils.add_csv_row(user_course_analytics_data, row)
              end
            end
          rescue => e
            Utils.log_error e
            it("encountered an error with UID #{student.uid} term #{test.term}") { fail }
          end
        end
      end
    end
  rescue => e
    Utils.log_error e
    it('encountered an unexpected error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
