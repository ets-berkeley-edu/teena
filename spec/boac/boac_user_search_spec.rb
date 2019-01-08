require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  test_config = BOACTestConfig.new
  test_config.user_search NessieUtils.get_all_students
  # Avoid using ASC 'inactive' students since they won't be visible if the dept is ASC
  test_config.max_cohort_members.keep_if &:active_asc if test_config.dept == BOACDepartments::ASC

  before(:all) do
    @driver = Utils.launch_browser test_config.chrome_profile
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @homepage.dev_auth test_config.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'search' do

    after(:all) { @homepage.log_out }

    test_config.max_cohort_members.each do |s|

      it "finds UID #{s.uid} with the complete first name" do
        @search_page.search s.first_name
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with a partial first name" do
        @search_page.search s.first_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with the complete last name" do
        @search_page.search s.last_name
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with a partial last name" do
        @search_page.search s.last_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with the complete first and last name" do
        @search_page.search "#{s.first_name} #{s.last_name}"
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with the complete last and first name" do
        @search_page.search "#{s.last_name}, #{s.first_name}"
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with a partial first and last name" do
        @search_page.search "#{s.first_name[0..2]} #{s.last_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with a partial last and first name" do
        @search_page.search "#{s.last_name[0..2]}, #{s.first_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with the complete SID" do
        @search_page.search s.sis_id.to_s
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end

      it "finds UID #{s.uid} with a partial SID" do
        @search_page.search s.sis_id.to_s[0..4]
        expect(@search_page.student_in_search_result?(@driver, s)).to be true
      end
    end

    it 'limits results to 50' do
      @search_page.search '303'
      expect(@search_page.student_search_results_count).to be > 50
      expect(@search_page.student_row_sids.length).to eql(50)
    end
  end

end
