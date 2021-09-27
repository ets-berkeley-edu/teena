require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test_config = BOACTestConfig.new
      test_config.search_appointments
      search_word_count = BOACUtils.search_word_count
      student_searches = []
      all_advising_note_authors = NessieTimelineUtils.get_all_advising_note_authors

      test_config.test_students.each do |student|

        begin
          appt_searches = []
          expected_boa_appts = BOACUtils.get_student_appts(student, test_config.students)
          expected_boa_appts.delete_if &:deleted_date
          expected_sis_appts = NessieTimelineUtils.get_sis_appts student
          expected_appts = expected_boa_appts + expected_sis_appts
          if expected_appts.any?
            expected_appts.each { |appt| appt_searches << BOACUtils.generate_appt_search_query(student, appt) }
          else
            logger.warn "Bummer, UID #{student.uid} has no appointments to search for"
          end
          student_searches << {student: student, appt_searches: appt_searches[0..(BOACUtils.search_max_searches - 1)]}

        rescue => e
          Utils.log_error e
          it("hit an error collecting test searches for UID #{student.uid}") { fail }
        end
      end

      # EXECUTE SEARCHES

      @driver = Utils.launch_browser test_config.chrome_profile
      @homepage = BOACHomePage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @homepage.dev_auth test_config.advisor
      @homepage.load_page

      student_searches.each do |search|

        logger.info "Beginning appointment search tests for UID #{search[:student].uid}"

        search[:appt_searches].each do |appt_search|

          begin

            # Search string

            if appt_search[:string]

              @homepage.set_notes_date_range(nil, nil)
              @homepage.type_note_appt_string_and_enter appt_search[:string]

              string_results_count = @search_results_page.appt_results_count

              it("returns results when searching with the first #{search_word_count} words in #{appt_search[:test_case]}") { expect(string_results_count).to be > 0 }
              it("shows no more than 20 results when searching with the first #{search_word_count} words in #{appt_search[:test_case]}") { expect(string_results_count).to be <= 20 }

              if string_results_count < 20
                student_result_returned = @search_results_page.appt_in_search_result?(appt_search[:appt])
                it("returns a result when searching with the first #{search_word_count} words in #{appt_search[:test_case]}") { expect(student_result_returned).to be true }

                if student_result_returned
                  result = @search_results_page.appt_result(search[:student], appt_search[:appt])
                  it("appointment search shows the student name for #{appt_search[:test_case]}") { expect(result[:student_name]).to eql(search[:student].full_name) }
                  it("appointment search shows the student SID for #{appt_search[:test_case]}") { expect(result[:student_sid]).to eql(search[:student].sis_id) }
                  it("appointment search shows a snippet of #{appt_search[:test_case]}") { expect(result[:snippet].gsub(/\W/, '')).to include(appt_search[:string].gsub(/\W/, '')) }
                  it("appointment search shows the appointment date on #{appt_search[:test_case]}") { expect(result[:date]).to eql(appt_search[:appt].created_date.strftime('%b %-d, %Y')) }
                  if appt_search[:appt].advisor
                    it("appointment search shows the advisor name on #{appt_search[:test_case]}") { expect(result[:advisor_name]).to eql(appt_search[:appt].advisor.full_name) }
                  else
                    it("appointment search shows no advisor name on #{appt_search[:test_case]}") { expect(result[:advisor_name]).to be_nil }
                  end
                end
              else
                logger.warn "Skipping a search string test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
              end

            else
              logger.warn "Skipping a search string test with appointment ID #{appt_search[:appt].id} because the description is too short"
            end

            # Topics

            @homepage.reset_search_options_notes_subpanel

            all_topics = Topic::TOPICS.select(&:for_appts).map &:name
            appt_topics = all_topics.select { |topic_name| appt_search[:appt].topics.include? topic_name.upcase }
            non_appt_topics = all_topics - appt_topics

            appt_topics.each do |appt_topic|
              topic = Topic::TOPICS.find { |t| t.name == appt_topic }
              @homepage.select_note_topic topic
              if appt_search[:string].to_s.empty?
                @homepage.click_search_button
              else
                @homepage.type_note_appt_string_and_enter appt_search[:string]
              end
              topic_results_count = @search_results_page.appt_results_count

              if topic_results_count < 20
                topic_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                it("returns a result when searching with the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} and matching topic #{topic.name}") do
                  expect(topic_match).to be true
                end

                non_topic = Topic::TOPICS.find { |t| t.name == non_appt_topics.first }
                @homepage.select_note_topic non_topic
                @homepage.enter_search_string appt_search[:string]
                @homepage.click_search_button
                topic_no_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                it "returns no result when searching with the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} and non-matching topic #{topic.name}" do
                  expect(topic_no_match).to be false
                end
              else
                logger.warn "Skipping a search string + topic test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
              end
            end

            # Posted by (the user who met with the student rather than the appointment creator)

            if appt_search[:appt].advisor

              @homepage.reset_search_options_notes_subpanel
              logger.info "Checking filters for #{appt_search[:test_case]} posted by UID #{appt_search[:appt].advisor.uid}"

              if appt_search[:appt].advisor.uid == test_config.advisor.uid
                logger.info 'Searching for an appointment belonging to the logged in advisor'

                # Posted by you
                @homepage.select_notes_posted_by_you
                @homepage.type_note_appt_string_and_enter appt_search[:string]
                you_posted_results_count = @search_results_page.appt_results_count

                if you_posted_results_count < 20
                  you_posted_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                  it "returns a result when searching with the first #{search_word_count} words in #{appt_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                    expect(you_posted_match).to be true
                  end
                else
                  logger.warn "Skipping a search string + posted-by-you test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                end

                # Posted by anyone
                @homepage.select_notes_posted_by_anyone
                @homepage.click_search_button
                if appt_search[:string].to_s.empty?
                  validation_error_present = @homepage.verify_block { @homepage.fill_in_field_msg_element.when_visible 1 }
                  it "requires a non-empty search string when searching for #{appt_search[:test_case]} and posted by anyone" do
                    expect(validation_error_present).to be true
                  end
                else
                  anyone_posted_results_count = @search_results_page.appt_results_count

                  if anyone_posted_results_count < 20
                    anyone_posted_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                    it "returns a result when searching with the first #{search_word_count} words in #{appt_search[:test_case]} and posted by anyone" do
                      expect(anyone_posted_match).to be true
                    end
                  else
                    logger.warn "Skipping a search string + posted-by-anyone test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                  end
                end

              else
                logger.info 'Searching for an appointment posted by someone other than the logged in advisor'

                # Posted by you
                @homepage.enter_search_string appt_search[:string]
                @homepage.select_notes_posted_by_you
                @homepage.click_search_button
                you_posted_results_count = @search_results_page.appt_results_count

                if you_posted_results_count < 20
                  you_posted_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                  it "returns no result when searching with the first #{search_word_count} words in #{appt_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                    expect(you_posted_match).to be_falsey
                  end
                else
                  logger.warn "Skipping a search string + posted-by-you test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                end

                # Posted by anyone
                @homepage.select_notes_posted_by_anyone
                @homepage.enter_search_string appt_search[:string]
                @homepage.click_search_button
                if appt_search[:string].to_s.empty?
                  validation_error_present = @homepage.verify_block { @homepage.fill_in_field_msg_element.when_visible 1 }
                  it "requires a non-empty search string when searching for #{appt_search[:test_case]} and posted by anyone" do
                    expect(validation_error_present).to be true
                  end
                else
                  anyone_posted_results_count = @search_results_page.appt_results_count

                  if anyone_posted_results_count < 20
                    anyone_posted_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                    it "returns a result when searching with the first #{search_word_count} words '#{appt_search[:string]}' in #{appt_search[:test_case]} and posted by anyone" do
                      expect(anyone_posted_match).to be true
                    end
                  else
                    logger.warn "Skipping a search string + posted-by-anyone test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                  end
                end
              end

              # Advisor (the user who met with the student rather than the user who created the appointment)

              if (author = NessieTimelineUtils.get_advising_note_author(appt_search[:appt].advisor.uid))

                @homepage.reset_search_options_notes_subpanel
                @homepage.set_notes_author(author_name = "#{author[:first_name]} #{author[:last_name]}")
                if appt_search[:string].to_s.empty?
                  @homepage.click_search_button
                else
                  @homepage.type_note_appt_string_and_enter appt_search[:string]
                end
                author_results_count = @search_results_page.appt_results_count

                if author_results_count < 20
                  author_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                  it("returns a result when searching with the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} and author name #{author_name}") do
                    expect(author_match).to be true
                  end
                else
                  logger.warn "Skipping a search string + name test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                end

                other_author = loop do
                  a = all_advising_note_authors.sample
                  break a unless a[:uid] == appt_search[:appt].advisor.uid
                end

                @homepage.set_notes_author(other_author_name = "#{other_author[:first_name]} #{other_author[:last_name]}")
                @homepage.click_search_button
                other_author_results_count = @search_results_page.appt_results_count

                if other_author_results_count < 20
                  other_author_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
                  it("returns no result when searching with the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} and non-matching author name #{other_author_name}") do
                    expect(other_author_match).to be false
                  end
                else
                  logger.warn "Skipping a search string + name test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
                end

              else
                logger.warn "Bummer, appointment ID #{appt_search[:appt].id} has no identifiable author name"
              end
            else
              logger.warn "Appointment ID #{appt_search[:appt].id} has no associated advisor"
            end

            # Student

            @homepage.reset_search_options_notes_subpanel
            @homepage.set_notes_student search[:student]
            if appt_search[:string].to_s.empty?
              @homepage.click_search_button
            else
              @homepage.type_note_appt_string_and_enter appt_search[:string] unless appt_search[:string].to_s.empty?
            end
            student_results_count = @search_results_page.appt_results_count

            if student_results_count < 20
              student_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
              it("returns a result when searching with the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} and student #{search[:student].sis_id}") do
                expect(student_match).to be true
              end
            else
              logger.warn "Skipping a search string + student name test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
            end

            # Appointment date

            appt_date = Date.parse(appt_search[:appt].created_date.to_s)
            logger.info "Checking date filters for an appointment on #{appt_date}"

            @homepage.reset_search_options_notes_subpanel
            @homepage.set_notes_date_range(appt_date, appt_date + 1)
            if appt_search[:string].to_s.empty?
              @homepage.click_search_button
            else
              @homepage.type_note_appt_string_and_enter appt_search[:string]
            end
            range_start_results_count = @search_results_page.appt_results_count

            if range_start_results_count < 20
              range_start_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
              it "returns a result when searching the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} in a range starting with appointment date" do
                expect(range_start_match).to be true
              end
            else
              logger.warn "Skipping a search string + date range test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(appt_date - 1, appt_date)
            @homepage.click_search_button
            range_end_results_count = @search_results_page.appt_results_count

            if range_end_results_count < 20
              range_end_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
              it "returns a result when searching the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} in a range ending with last updated date" do
                expect(range_end_match).to be true
              end
            else
              logger.warn "Skipping a search string + date range test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(appt_date - 30, appt_date - 1)
            @homepage.click_search_button
            range_before_results_count = @search_results_page.appt_results_count

            if range_before_results_count < 20
              range_before_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
              it "returns no result when searching the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} in a range before last updated date" do
                expect(range_before_match).to be false
              end
            else
              logger.warn "Skipping a search string + date range test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(appt_date + 1, appt_date + 30)
            @homepage.click_search_button
            range_after_results_count = @search_results_page.appt_results_count

            if range_after_results_count < 20
              range_after_match = @search_results_page.appt_in_search_result?(appt_search[:appt])
              it "returns no result when searching the first #{search_word_count} words in appointment ID #{appt_search[:appt].id} in a range after last updated date" do
                expect(range_after_match).to be false
              end
            else
              logger.warn "Skipping a search string + date range test with appointment ID #{appt_search[:appt].id} because there are more than 20 results"
            end

          rescue => e
            Utils.log_error e
            Utils.save_screenshot(@driver, "#{Time.now.to_i.to_s}")
            it("hit an error executing an appointment search test for #{appt_search[:test_case]}") { fail }
          end
        end
      end

    rescue => e
      Utils.log_error e
      it('test hit an error initializing') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end
