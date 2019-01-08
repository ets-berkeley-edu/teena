require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    if Utils.headless?

      logger.warn 'This script requires admin Canvas access and cannot be run headless. Terminating.'

    else

      test = BOACTestConfig.new
      test.last_activity NessieUtils.get_all_students
      pages_tested = []

      # Test Last Activity using the current term rather than past term
      test.term = BOACUtils.term
      logger.info "Checking term #{test.term}"

      heading = %w(Term Course SiteId TtlStudents TtlLogins UID CanvasLastActivity CaliperLastActivity NessieLastActivity StudentPageActivity CanvasContext StudentPageContext)
      last_activity_csv = Utils.create_test_output_csv('boac-last-activity.csv', heading)

      caliper_error_csv = Utils.create_test_output_csv('caliper-errors.csv', %w(SiteId CanvasId UID CanvasLastActivity CaliperLastActivity DiffSeconds P/F))

      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @cal_net_page = Page::CalNetPage.new @driver
      @canvas_page = Page::CanvasPage.new @driver
      @student_page = BOACStudentPage.new @driver

      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password, 'https://bcourses.berkeley.edu')
      @homepage.dev_auth test.advisor

      test.max_cohort_members.each do |test_student|
        begin

          # Get the user API data for the test student to determine which courses to check
          api_student_page = BOACApiUserAnalyticsPage.new @driver
          api_student_page.get_data(@driver, test_student)
          term = api_student_page.terms.find { |t| api_student_page.term_name(t) == test.term }
          if term
            term_id = api_student_page.term_id term

            api_student_page.courses(term).each do |course|

              course_sis_data = api_student_page.course_sis_data course
              logger.info "Checking course #{course_sis_data[:code]}"

              api_student_page.sections(course).each do |section|
                begin

                  # Only test a primary section that hasn't been tested already
                  section_data = api_student_page.section_sis_data section
                  if api_student_page.section_sis_data(section)[:primary] && !pages_tested.include?("#{term_id} #{section_data[:ccn]}")
                    pages_tested << "#{term_id} #{section_data[:ccn]}"

                    # Get all the students in the course who will be visible in BOAC
                    api_section_page = BOACApiSectionPage.new @driver
                    api_section_page.get_data(@driver, term_id, section_data[:ccn])
                    visible_classmates = test.dept_students.select { |s| api_section_page.student_uids.include? s.uid }

                    # Only test courses with sites
                    if api_section_page.student_site_ids(visible_classmates.first).any?

                      visible_student_data = []
                      all_sites_data = []

                      # Collect all the Canvas sites associated with each student who's visible in BOAC
                      visible_classmates.each do |classmate|
                        begin

                          api_classmate_page = BOACApiUserAnalyticsPage.new @driver
                          api_classmate_page.get_data(@driver, classmate)
                          term = api_classmate_page.terms.find { |t| api_classmate_page.term_name(t) == test.term }
                          classmate_course = api_classmate_page.courses(term).find { |c| api_classmate_page.course_section_ccns(c).include? section_data[:ccn] }
                          classmate_section = api_classmate_page.sections(classmate_course).find { |s| api_classmate_page.section_sis_data(s)[:ccn] == section_data[:ccn] }
                          classmate_sites = api_classmate_page.course_sites classmate_course
                          classmate_data = {
                            :student => classmate,
                            :course_code => api_classmate_page.course_display_name(classmate_course),
                            :section_format => "#{api_classmate_page.section_sis_data(classmate_section)[:component]} #{api_classmate_page.section_sis_data(classmate_section)[:number]}",
                            :sites => (classmate_sites.map do |site|
                              {
                                :site_id => api_student_page.site_metadata(site)[:site_id],
                                :site_code => api_student_page.site_metadata(site)[:code],
                                :last_activity_nessie => Time.at(api_student_page.nessie_last_activity(site)[:score].to_i).utc
                              }
                            end)
                          }
                          visible_student_data << classmate_data
                        end
                      end

                      # Get the unique sites associated with the course
                      site_ids = visible_student_data.map { |d| d[:sites].map { |s| s[:site_id] } }
                      site_ids.flatten!
                      site_ids.uniq!
                      logger.info "Canvas course site IDs associated with this course are #{site_ids}"

                      # Load the student page for each student, and collect all the last activity info shown for each site
                      visible_student_data.each do |d|
                        @student_page.load_page d[:student]
                        @student_page.scroll_to_bottom
                        @student_page.expand_course_data(test.term, d[:course_code])
                        d[:sites].each do |s|
                          s.merge!(:last_activity_student_page => @student_page.visible_last_activity(test.term, d[:course_code], d[:sites].index(s)))
                        end
                      end

                      # Load each course site, and collect the last activity shown for every student visible in BOAC
                      site_ids.each do |site_id|
                        all_site_students = @canvas_page.get_students(Course.new({:site_id => site_id}), nil, 'https://bcourses.berkeley.edu')
                        visible_student_data.each do |student_data|
                          if (student_data[:sites].map { |s| s[:site_id] }).include? site_id
                            matching_student = all_site_students.find { |s| s.uid == student_data[:student].uid }
                            student_data[:student].canvas_id = matching_student.canvas_id
                            student_last_activity = @canvas_page.roster_user_last_activity student_data[:student].uid
                            site_to_update = student_data[:sites].find { |site| site[:site_id] == site_id }
                            site_to_update.merge!(:last_activity_canvas => (Time.parse(student_last_activity).utc if student_last_activity))
                          end
                        end

                        # Collect the last activity shown for students not visible in BOAC
                        invisible_student_site_data = []
                        invisible_students = all_site_students.reject { |student| visible_classmates.map(&:uid).include? student.uid }
                        invisible_students.each do |invisible_student|
                          last_activity = @canvas_page.roster_user_last_activity invisible_student.uid
                          student_data = {
                            :student => invisible_student,
                            :sites => [
                              {
                                :site_id => site_id,
                                :last_activity_canvas => (Time.parse(last_activity).utc if last_activity)
                              }
                            ]
                          }
                          invisible_student_site_data << student_data
                        end

                        # Aggregate the Canvas data for the site
                        all_last_activities = all_site_students.map do |student|
                          student_data = (visible_student_data + invisible_student_site_data).find { |data| data[:student].uid == student.uid }
                          site = student_data[:sites].find { |s| s[:site_id] == site_id }
                          site[:last_activity_canvas]
                        end
                        all_site_data = {
                          :site_id => site_id,
                          :student_count => all_site_students.length,
                          :last_activity_dates => all_last_activities
                        }
                        all_sites_data << all_site_data

                        # CALIPER DATA

                        (visible_student_data + invisible_student_site_data).each do |student_data|

                          student_data[:sites].each do |student_site|
                            student_site.merge!(:last_activity_caliper => NessieUtils.get_caliper_last_activity(student_data[:student], student_site[:site_id]))

                            if NessieUtils.include_caliper_tests

                              if student_site[:last_activity_canvas].nil?
                                it "Caliper has no last activity data for site #{student_site[:site_id]}, UID #{student_data[:student].uid}, Canvas ID #{student_data[:student].canvas_id}" do
                                  expect(student_site[:last_activity_caliper]).to be_nil
                                end

                              else
                                if student_site[:last_activity_caliper].nil?
                                  it("Caliper has no last activity data for site #{student_site[:site_id]}, UID #{student_data[:student].uid}, Canvas ID #{student_data[:student].canvas_id}, but it should") { fail }

                                else
                                  hours_since = (Time.now.utc - student_site[:last_activity_canvas]) / 3600
                                  if hours_since < NessieUtils.canvas_data_lag_hours
                                    logger.warn "Skipping Caliper last activity check for UID #{student_data[:student].uid} in site ID #{student_site[:site_id]} since it was #{hours_since.round 1} hours ago"

                                  else
                                    diff = (student_site[:last_activity_caliper] - student_site[:last_activity_canvas]).abs
                                    it "Caliper has the right last activity data for site #{student_site[:site_id]}, UID #{student_data[:student].uid}, Canvas ID #{student_data[:student].canvas_id}" do
                                      expect(diff).to be < NessieUtils.caliper_time_margin
                                    end

                                    result = (diff > NessieUtils.caliper_time_margin) ? 'Fail' : 'Pass'
                                    error_data = [student_site[:site_id], student_data[:student].canvas_id, student_data[:student].uid,
                                                  student_site[:last_activity_canvas], student_site[:last_activity_caliper], (student_site[:last_activity_caliper] - student_site[:last_activity_canvas]), result]
                                    Utils.add_csv_row(caliper_error_csv, error_data)
                                    logger.debug "Canvas vs Caliper diff is #{diff} on site #{student_site[:site_id]} UID #{student_data[:student].uid}"
                                  end
                                end
                              end
                            end
                          end
                        end
                      end

                      visible_student_data.each do |student_data|
                        begin

                          student_data[:sites].each do |student_site|

                            test_case = "UID #{student_data[:student].uid} in Canvas site ID #{student_site[:site_id]}"
                            logger.info "Checking last activity for #{test_case}"

                            it("last activity date is not older than the Caliper date for UID #{student_data[:student].uid} in Canvas site ID #{student_site[:site_id]}") { expect(student_site[:last_activity_nessie]).to be >= student_site[:last_activity_caliper] }

                            # Record the activity data to a CSV
                            site = all_sites_data.find { |s| s[:site_id] == student_site[:site_id] }
                            total_logins = site[:last_activity_dates].compact.length
                            more_recent_logins = student_site[:last_activity_canvas] ? site[:last_activity_dates].compact.select { |date| date > student_site[:last_activity_canvas] } : []

                            data_to_record = [test.term, course_sis_data[:code], site[:site_id], site[:last_activity_dates].length, total_logins,
                                              student_data[:student].uid, student_site[:last_activity_canvas], student_site[:last_activity_caliper],
                                              student_site[:last_activity_nessie], student_site[:last_activity_student_page][:days],
                                              (("#{more_recent_logins.length} out of #{site[:last_activity_dates].length} enrolled students have done so more recently.") if more_recent_logins),
                                              student_site[:last_activity_student_page][:context]]
                            Utils.add_csv_row(last_activity_csv, data_to_record)

                            # SITE DETAIL

                            if student_site[:last_activity_canvas].nil?
                              it("shows 'never' Last Activity in the BOAC student page for #{test_case}") { expect(student_site[:last_activity_student_page][:days]).to include('never') }

                              # Note if the site could trigger a 'no activity' alert
                              # TODO - account for 'start of session'
                              student_site.merge!(:no_activity_alert => true) if total_logins.to_f / site[:last_activity_dates].length.to_f >= 0.8

                            else

                              day_count = (Date.today - Date.parse(student_site[:last_activity_canvas].localtime.to_s)).to_i
                              hours_since = (Time.now.utc - student_site[:last_activity_canvas]) / 3600
                              if  hours_since < NessieUtils.canvas_data_lag_hours
                                logger.warn "Skipping Caliper last activity check for #{test_case} since it was #{hours_since.round 1} hours ago"

                              else

                                (day_count == 1) ?
                                    (it("shows 'yesterday' Last Activity on the student page for #{test_case}") { expect(student_site[:last_activity_student_page][:days]).to eql('yesterday') }) :
                                    (it("shows '#{day_count} days ago' Last Activity on the student page for #{test_case}") { expect(student_site[:last_activity_student_page][:days]).to eql("#{day_count} days ago") })

                                if BOACUtils.last_activity_context
                                  it("shows #{site[:last_activity_dates].length} total students for #{test_case}") { expect(student_site[:last_activity_student_page][:context]).to include("out of #{site[:last_activity_dates].length} enrolled students") }
                                end
                              end

                              # Note if the site could trigger an 'infrequent activity' alert
                              student_site.merge!(:infrequent_activity_alert => true) if (day_count >= 14) && (more_recent_logins.length.to_f / site[:last_activity_dates].length.to_f >= 0.8)

                            end
                          end

                          # ALERTS

                          # To verify that an inactivity alert does NOT exist, compare without the 'x days' portion of the alerts
                          user_alert_msgs = BOACUtils.get_students_alerts([student_data[:student]]).map &:message
                          truncated_alert_msgs = user_alert_msgs.map { |msg| msg.gsub(/( was )\d+( days ago.)/, '') }
                          logger.debug "UID #{student_data[:student].uid} alerts: #{user_alert_msgs}"

                          test_case = "UID #{student_data[:student].uid} in #{student_data[:course_code]}"
                          logger.debug "Checking #{test_case}"

                          # Never show alerts for DeCal courses
                          if (/\A[A-Z\s]+1?9[89][A-Z]?[A-Z]?/ === student_data[:course_code].gsub("#{student_data[:section_format]}", '').strip) && !student_data[:section_format].include?('LEC')
                            it("shows no 'No activity!' alert for #{test_case}") { expect(user_alert_msgs).not_to include("No activity! Student has never visited the #{student_data[:course_code]} bCourses site for #{BOACUtils.term}.") }
                            it("shows no infrequent activity alert for #{test_case}") { expect(truncated_alert_msgs).not_to include("Infrequent activity! Last #{student_data[:course_code]} bCourses activity") }

                          else
                            # Alerts are not shown for sites below an activity threshold, so get the student's 'active' sites
                            active_student_sites = student_data[:sites].select do |student_site|
                              course_site = all_sites_data.find { |course_site| course_site[:site_id] == student_site[:site_id]}
                              (course_site[:last_activity_dates].compact.length.to_f / course_site[:student_count].to_f > 0.8)
                            end
                            logger.debug "Active sites are #{active_student_sites}"

                            # Get the sites that could trigger an alert
                            infrequent_alert_triggers = active_student_sites.select { |site| site[:infrequent_activity_alert] }
                            no_activity_alert_triggers = active_student_sites.select { |site| site[:no_activity_alert] }

                            # If all the active sites could trigger 'no activity' alerts for the student, then show a 'no activity' alert
                            if no_activity_alert_triggers.length == active_student_sites.length
                              it("shows a 'No activity!' alert for #{test_case}") { expect(user_alert_msgs).to include("No activity! Student has never visited the #{student_data[:course_code]} bCourses site for #{BOACUtils.term}.") }
                              it("shows no infrequent activity alert for #{test_case}") { expect(truncated_alert_msgs).not_to include("Infrequent activity! Last #{student_data[:course_code]} bCourses activity") }

                            # If all the active sites could trigger an alert and some could trigger an 'infrequent activity' alert,
                            # then show an 'infrequent' alert for the one with the most recent activity
                            elsif infrequent_alert_triggers.any? && (no_activity_alert_triggers.length + infrequent_alert_triggers.length == active_student_sites.length)
                              most_recent = infrequent_alert_triggers.max_by { |site| site[:last_activity_canvas] }
                              day_count = (Date.today - Date.parse(most_recent[:last_activity_canvas].to_s)).to_i
                              it("shows an infrequent activity alert for #{test_case}") { expect(user_alert_msgs).to include("Infrequent activity! Last #{student_data[:course_code]} bCourses activity was #{day_count} days ago.") }
                              it("shows no 'No activity!' alert for #{test_case}") { expect(user_alert_msgs).not_to include("No activity! Student has never visited the #{student_data[:course_code]} bCourses site for #{BOACUtils.term}.") }

                            else
                              it("shows no 'No activity!' alert for #{test_case}") { expect(user_alert_msgs).not_to include("No activity! Student has never visited the #{student_data[:course_code]} bCourses site for #{BOACUtils.term}.") }
                              it("shows no infrequent activity alert for #{test_case}") { expect(truncated_alert_msgs).not_to include("Infrequent activity! Last #{student_data[:course_code]} bCourses activity") }
                            end
                          end

                        rescue => e
                          Utils.log_error e
                          it("hit an error with #{student_data[:student].uid}") { fail }
                        end
                      end

                    else
                      logger.warn "There are no Canvas sites to check for term #{test.term} CCN #{section_data[:ccn]}, skipping"
                    end
                  end

                rescue => e
                  Utils.log_error e
                  it("hit an error with term #{test.term} CCN #{section_data[:ccn]}") { fail }
                end
              end
            end
          else
            logger.warn "UID #{test_student.uid} has no enrollments in #{test.term}"
          end

        rescue => e
          Utils.log_error e
          it("hit an error with #{test.default_cohort.name} UID #{test_student.uid}") { fail }
        end
      end
    end

  rescue => e
    Utils.log_error e
    it('hit an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
