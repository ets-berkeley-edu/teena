require_relative '../../util/spec_helper'

describe 'A Physics advisor using BOAC' do

  include Logging

  test_asc = BOACTestConfig.new
  test_asc.user_role_asc

  test_coe = BOACTestConfig.new
  test_coe.user_role_coe

  test_physics = BOACTestConfig.new
  test_physics.user_role_physics

  overlap_students = ((test_asc.dept_students & test_physics.dept_students) + (test_coe.dept_students & test_physics.dept_students)).uniq
  coe_only_students = test_coe.dept_students - overlap_students

  before(:all) do
    @driver = Utils.launch_browser test_asc.chrome_profile
    @admin_page = BOACAdminPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_user_analytics_page = BOACApiStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new @driver
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test_physics.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a GPA filter') { expect(@filtered_cohort_page.new_filter_option_by_key('gpaRanges').visible?).to be true }
    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option_by_key('levels').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option_by_key('majors').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option_by_key('unitRanges').visible?).to be true }
    it('sees a Transfer Student filter') { expect(@filtered_cohort_page.new_filter_option_by_key('transfer').visible?).to be true }
    it('sees an Expected Graduation Term filter') { expect(@filtered_cohort_page.new_filter_option_by_key('expectedGradTerms').visible?).to be true }
    it('sees a Last Name filter') { expect(@filtered_cohort_page.new_filter_option_by_key('lastNameRange').visible?).to be true }
    it('sees no Advisor filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coeAdvisorLdapUids').exists?).to be false }
    it('sees no Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coeEthnicities').exists?).to be false }
    it('sees no \'Gender (COE)\' filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coeGenders').exists?).to be false }
    it('sees no PREP filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coePrepStatuses').exists?).to be false }
    it('sees no Inactive filter') { expect(@filtered_cohort_page.new_filter_option_by_key('isInactiveCoe').visible?).to be false }
    it('sees no Intensive filter') { expect(@filtered_cohort_page.new_filter_option_by_key('inIntensiveCohort').visible?).to be false }
    it('sees no Team filter') { expect(@filtered_cohort_page.new_filter_option_by_key('groupCodes').visible?).to be false }
  end

  context 'visiting Everyone\'s Cohorts' do

    it 'sees only filtered cohorts created by Physics advisors' do
      expected_cohort_names = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::PHYSICS).map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_cohort_names - visible_cohort_names}. Present but not expected: #{visible_cohort_names - expected_cohort_names}") do
        visible_cohort_names == expected_cohort_names
      end
    end

    it 'cannot hit a non-Physics filtered cohort URL' do
      coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
      coe_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
          logger.warn('Skipping test for Physics access to CoE cohorts because CoE has no cohorts.')
    end
  end

  context 'performing a user search' do

    it 'sees non-Physics students in search results' do
      @search_page.search_non_note coe_only_students.first.sis_id
      expect(@search_page.student_search_results_count).to eql(1)
    end
  end

  context 'looking for admin functions' do

    it 'can load the admin page' do
      @homepage.load_page
      @homepage.click_header_dropdown
      expect(@homepage.admin_link?).to be true
    end

    it 'can toggle demo mode' do
      @admin_page.load_page
      @admin_page.demo_mode_toggle_element.when_present Utils.short_wait
    end

    it('cannot download BOA user lists') { expect(@admin_page.download_users_button?).to be false }

    it 'can see no other admin functions' do
      BOACDepartments::DEPARTMENTS.each { |dept| expect(@admin_page.dept_tab_link_element(dept).exists?).to be false }
      expect(@admin_page.status_heading?).to be false
    end

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end
