require_relative '../../util/spec_helper'

describe 'An admin using BOAC' do

  include Logging

  all_students = NessieUtils.get_all_students
  test = BOACTestConfig.new
  test.user_role_admin all_students

  coe_only_students = all_students.select { |s| s.depts == [BOACDepartments::COE] }
  asc_only_students = all_students.select { |s| s.depts == [BOACDepartments::ASC] }

  everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts

  before(:all) do
    @driver = Utils.launch_browser test.chrome_profile
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_user_analytics_page = BOACApiUserAnalyticsPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new @driver
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @teams_page = BOACTeamsListPage.new @driver

    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'visiting Everyone\'s Cohorts' do

    before(:all) do
      @homepage.load_page
      @homepage.click_view_everyone_cohorts
    end

    it 'sees all filtered cohorts' do
      expected_cohort_names = everyone_cohorts.map(&:name).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:name).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    end

    it 'can hit the teams list' do
      @teams_page.load_page
      expect(@teams_page.teams.length).not_to be_zero
    end
  end

  context 'performing a user search' do

    it('sees CoE-only students in search results') do
      @search_page.search coe_only_students.first.sis_id
      expect(@search_page.student_search_results_count).to eql(1)
    end

    it('sees ASC-only students in search results') do
      @search_page.search asc_only_students.first.sis_id
      expect(@search_page.student_search_results_count).to eql(1)
    end
  end

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option('Level').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option('Major').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option('Units Completed').visible?).to be true }
    it('sees a Advisor filter') { expect(@filtered_cohort_page.new_filter_option('Advisor').visible?).to be true }
    it('sees a Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option('Ethnicity').visible?).to be true }
    it('sees a Gender filter') { expect(@filtered_cohort_page.new_filter_option('Gender').visible?).to be true }
    it('sees a PREP filter') { expect(@filtered_cohort_page.new_filter_option('PREP').visible?).to be true }
    it('sees an Inactive COE filter') { expect(@filtered_cohort_page.new_filter_option('Inactive (COE)').visible?).to be true }
    it('sees a Probation filter') { expect(@filtered_cohort_page.new_filter_option('Probation').visible?).to be true }
    it('sees an Inactive ASC filter') { expect(@filtered_cohort_page.new_filter_option('Inactive (ASC)').visible?).to be true }
    it('sees an Intensive filter') { expect(@filtered_cohort_page.new_filter_option('Intensive').visible?).to be true }
    it('sees a Team filter') { expect(@filtered_cohort_page.new_filter_option('Team').visible?).to be true }
  end

  context 'visiting a class page' do

    it 'sees all students in a section endpoint' do
      @api_section_page.get_data(@driver, '2178', '13826')
      expect(asc_only_students.map(&:sis_id) & @api_section_page.student_sids).not_to be_empty
      expect(coe_only_students.map(&:sis_id) & @api_section_page.student_sids).not_to be_empty
    end
  end

  context 'visiting a student page' do

    it 'can see an ASC student page' do
      @student_page.load_page asc_only_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(asc_only_students.first.full_name.split(',').reverse.join(' ').strip)
    end

    it 'can see a CoE student page' do
      @student_page.load_page coe_only_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(coe_only_students.first.full_name.split(',').reverse.join(' ').strip)
    end

    it 'can see the ASC profile data for an ASC student on the user analytics page' do
      @api_user_analytics_page.get_data(@driver, asc_only_students.first)
      expect(@api_user_analytics_page.asc_profile).not_to be_nil
    end
  end

  context 'looking for inactive students' do

    it('sees no link to Inactive Students') { expect(@homepage.inactive_cohort_link?).to be false }

    it 'can hit the Inactive Students page' do
      @filtered_cohort_page.load_inactive_students_page
      @filtered_cohort_page.wait_until(Utils.medium_wait) { @filtered_cohort_page.list_view_uids.any? }
    end
  end

  context 'looking for intensive students' do

    it('sees no link to Intensive Students') { expect(@homepage.intensive_cohort_link?).to be false }

    it 'can hit the Intensive Students page' do
      @filtered_cohort_page.load_intensive_students_page
      @filtered_cohort_page.wait_until(Utils.medium_wait) { @filtered_cohort_page.list_view_uids.any? }
    end
  end

  context 'visiting the admin page' do

    it('sees a link to the admin page') { @homepage.click_admin_link }

    # TODO - it('sees all the authorized users')

    # TODO - it('can authenticate as one of the authorized users')
  end

end