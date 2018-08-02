require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    test_config = BOACUtils.get_navigation_test_config
    test_config.cohort.name = 'My Students' if test_config.dept == BOACDepartments::COE

    test_search_criteria = BOACUtils.get_test_search_criteria
    unless test_config.dept == BOACDepartments::ASC
      test_search_criteria.each { |c| c.squads = nil }
      test_search_criteria.keep_if { |c| [c.levels, c.majors, c.gpa_ranges, c.units].compact.any? }
    end
    cohorts = test_search_criteria.map { |c| FilteredCohort.new({:search_criteria => c}) }

    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @matrix_page = Page::BOACPages::CohortPages::FilteredCohortMatrixPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth test_config.advisor
    @homepage.click_sidebar_create_filtered

    # Navigate the various cohort/student views using each of the test search criteria
    cohorts.each do |cohort|

      begin
        search = "#{cohort.search_criteria.squads && cohort.search_criteria.squads.map(&:name)}, #{cohort.search_criteria.levels}, #{cohort.search_criteria.majors}, #{cohort.search_criteria.gpa_ranges}, #{cohort.search_criteria.units}"

        # Every other search starts from list view
        if cohorts.index(cohort).even?

          # Make sure a list view button is present from the previous loop. If not, load a team cohort to obtain an initial list view.
          @cohort_page.load_cohort test_config.cohort unless @cohort_page.list_view_button?

          @cohort_page.click_list_view
          @cohort_page.perform_search cohort

          if cohort.member_count.zero?

            rows_visible = @cohort_page.player_link_elements.any?
            it("shows no results on list view cohort search for #{search}") { expect(rows_visible).to be false }

            logger.warn 'No results, skipping further tests'

          else

            # Page through results

            list_results_length = @cohort_page.visible_sids.length
            list_results_page = @cohort_page.list_view_current_page

            logger.info "Got #{list_results_length} list view results"

            it("shows the right list view cohort search results count for #{search}") { expect(cohort.member_count).to eql(list_results_length) }

            # Navigate to student page and back.

            student = User.new({:sis_id => @cohort_page.list_view_sids.last, :uid => @cohort_page.player_link_elements.last.attribute('id')})
            @cohort_page.click_player_link student
            @driver.navigate.back

            list_search_preserved = @cohort_page.search_criteria_selected? cohort.search_criteria
            list_results_count_preserved = @cohort_page.verify_block { @cohort_page.wait_until { @cohort_page.results_count == cohort.member_count } }
            list_results_page_preserved = @cohort_page.list_view_page_selected? list_results_page

            it("preserves cohort search criteria #{search} when returning to list view from the student #{student.sis_id} page") { expect(list_search_preserved).to be true }
            it("preserves the cohort search criteria #{search} results count when returning to list view from the student #{student.sis_id} page") { expect(list_results_count_preserved).to be true }
            it("preserves the cohort search criteria #{search} results page when returning to list view from the student #{student.sis_id} page") { expect(list_results_page_preserved).to be true }

            # Switch to matrix view

            if cohort.member_count > 800

              button_disabled = @cohort_page.matrix_view_button_element.attribute 'disabled'
              it("disables the matrix button for #{search} with result count #{cohort.member_count}") { expect(button_disabled).to eql('true') }

            else

              @cohort_page.click_matrix_view
              @matrix_page.wait_for_matrix
              scatterplot_uids = @matrix_page.visible_matrix_uids @driver
              no_data_uids = @matrix_page.visible_no_data_uids

              logger.info "Got #{scatterplot_uids.length + no_data_uids.length} matrix view UIDs"

              matrix_search = @matrix_page.search_criteria_selected? cohort.search_criteria
              matrix_results_right = (scatterplot_uids.length + no_data_uids.length == cohort.member_count)

              it("preserves cohort search criteria #{search} when switching to matrix view") { expect(matrix_search).to be true }
              it("preserves the cohort search criteria #{search} results count when switching to matrix view") { expect(matrix_results_right).to be true }

              # Navigate to student page and back. Click a bubble if there are any; otherwise a 'no data' row.

              scatterplot_uids.any? ? @matrix_page.click_last_student_bubble(@driver) : @matrix_page.click_last_no_data_student
              @driver.navigate.back
              @matrix_page.wait_for_matrix
              scatterplot_uids = @matrix_page.visible_matrix_uids @driver
              no_data_uids = @matrix_page.visible_no_data_uids

              matrix_search_preserved = @matrix_page.search_criteria_selected? cohort.search_criteria
              matrix_results_count_preserved = (scatterplot_uids.length + no_data_uids.length == cohort.member_count)

              it("preserves cohort search criteria #{search} when returning to matrix view from the student page") { expect(matrix_search_preserved).to be true }
              it("preserves the cohort search criteria #{search} results count when returning to matrix view from the student page") { expect(matrix_results_count_preserved).to be true }
            end
          end

        # Every other search starts from matrix view
        else

          # Make sure a matrix view button is present. If not, load a team cohort to obtain matrix view.

          @matrix_page.load_cohort_matrix test_config.cohort unless @cohort_page.matrix_view_button?

          @matrix_page.perform_search cohort
          @matrix_page.wait_for_matrix
          scatterplot_uids = @matrix_page.visible_matrix_uids @driver
          no_data_uids = @matrix_page.visible_no_data_uids
          total_results = scatterplot_uids.length + no_data_uids.length

          logger.info "Got #{total_results} matrix view UIDs"

          it("shows the cohort search results count for #{search}") { expect(cohort.member_count).to eql(total_results) }

          if cohort.member_count.zero?

            bubbles_visible = @matrix_page.visible_matrix_uids(@driver).any?
            rows_visible = @matrix_page.visible_no_data_uids.any?

            it("shows no bubbles on matrix view cohort search for #{search}") { expect(bubbles_visible).to be false }
            it("shows no rows on matrix view cohort search for #{search}") { expect(rows_visible).to be false }

            logger.warn 'No results, skipping further tests'

          else

            # Navigate to student page and back. Click a bubble if there are any; otherwise a 'no data' row.

            scatterplot_uids.any? ? @matrix_page.click_last_student_bubble(@driver) : @matrix_page.click_last_no_data_student
            @driver.navigate.back
            @matrix_page.wait_for_matrix
            scatterplot_uids = @matrix_page.visible_matrix_uids @driver
            no_data_uids = @matrix_page.visible_no_data_uids

            matrix_search_preserved = @matrix_page.search_criteria_selected? cohort.search_criteria
            matrix_results_count_preserved = (scatterplot_uids.length + no_data_uids.length == cohort.member_count)

            it("preserves cohort search criteria #{search} when returning to matrix view from the student page") { expect(matrix_search_preserved).to be true }
            it("preserves the cohort search criteria #{search} results count when returning to matrix view from the student page") { expect(matrix_results_count_preserved).to be true }

            # Switch to list view, and page through results.

            @matrix_page.click_list_view
            results_length = @cohort_page.visible_sids.length
            list_results_page = @cohort_page.list_view_current_page

            logger.info "Got #{results_length} list view results"

            it("shows the cohort search results count for #{search}") { expect(cohort.member_count).to eql(results_length) }

            # Navigate to student page and back.

            student = User.new({:sis_id => @cohort_page.list_view_sids.last, :uid => @cohort_page.player_link_elements.last.attribute('id')})
            @cohort_page.click_player_link student
            @driver.navigate.back

            list_search_preserved = @cohort_page.search_criteria_selected? cohort.search_criteria
            list_results_count_preserved = @cohort_page.wait_until { @cohort_page.results_count == cohort.member_count }
            list_results_page_preserved = @cohort_page.list_view_page_selected? list_results_page

            it("preserves cohort search criteria #{search} when returning to list view from the student #{student.sis_id} page") { expect(list_search_preserved).to be true }
            it("preserves the cohort search criteria #{search} results count when returning to list view from the student #{student.sis_id} page") { expect(list_results_count_preserved).to be true }
            it("preserves the cohort search criteria #{search} results page when returning to list view from the student #{student.sis_id} page") { expect(list_results_page_preserved).to be true }
          end
        end

      rescue => e
        BOACUtils.log_error_and_screenshot(@driver, e, "cohort-#{cohorts.index cohort}")
        it("threw an error with #{search}") { fail }
      end
    end

  rescue => e
    Utils.log_error e
    it('threw an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
