require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  test = BOACTestConfig.new
  all_students = NessieUtils.get_all_students
  test.curated_groups all_students
  test_student = test.cohort_members.last
  logger.debug "Test student is UID #{test_student.uid} SID #{test_student.sis_id}"
  student_data = NessieUtils.applicable_user_search_data(all_students, test)

  # Initialize groups to be used later in the tests
  advisor_groups = [
    (group_1 = CuratedGroup.new({:name => "Group 1 #{test.id}"})),
    (group_2 = CuratedGroup.new({:name => "Group 2 #{test.id}"})),
    (group_3 = CuratedGroup.new({:name => "Group 3 #{test.id}"})),
    (group_4 = CuratedGroup.new({:name => "Group 4 #{test.id}"})),
    (group_5 = CuratedGroup.new({:name => "Group 5 #{test.id}"})),
    (group_6 = CuratedGroup.new({:name => "Group 6 #{test.id}"})),
    (group_7 = CuratedGroup.new({:name => "Group 7 #{test.id}"})),
    (group_8 = CuratedGroup.new({:name => "Group 8 #{test.id}"}))
  ]
  other_advisor = BOACUtils.get_admin_users.find { |u| u.uid != test.advisor.uid }
  pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor

  before(:all) do
    @driver = Utils.launch_browser test.chrome_profile
    @analytics_page = BOACApiUserAnalyticsPage.new @driver
    @homepage = BOACHomePage.new @driver
    @curated_page = BOACCuratedGroupPage.new @driver
    @filtered_page = BOACFilteredCohortPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @search_page = BOACSearchResultsPage.new @driver

    # Get enrollment data for test student for class page tests
    @homepage.dev_auth test.advisor
    @analytics_page.get_data(@driver, test_student)
    @term = @analytics_page.terms.first
    @course = @analytics_page.courses(@term).first

    # Create a default filtered cohort
    @homepage.load_page
    @filtered_page.search_and_create_new_cohort(test.default_cohort, test) unless test.default_cohort.id
  end

  after(:all) { Utils.quit_browser @driver }

  it 'curated groups can all be deleted' do
    pre_existing_groups.each do |c|
      @curated_page.load_page c
      @curated_page.delete_cohort c
    end
  end

  describe 'curated group creation' do

    before(:all) do
      @groups_created = []
      @group_created_from_filter = CuratedGroup.new({:name => "Group created from filtered cohort #{test.id}"})
      @group_created_from_class = CuratedGroup.new({:name => "Group created from class page #{test.id}"})
      @group_created_from_search = CuratedGroup.new({:name => "Group created from search results #{test.id}"})
    end

    it 'can be done using the filtered cohort list view curated group selector' do
      @filtered_page.load_cohort test.default_cohort
      @filtered_page.wait_for_student_list
      sids = @filtered_page.list_view_sids
      visible_members = all_students.select { |m| sids.include? m.sis_id }
      @filtered_page.selector_add_students_to_new_group(visible_members, @group_created_from_filter)
      @groups_created << @group_created_from_filter
    end

    it 'can be done using the class page list view curated group selector' do
      @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      sids = @class_page.class_list_view_sids
      visible_members = all_students.select { |m| sids.include? m.sis_id }
      @class_page.selector_add_students_to_new_group(visible_members, @group_created_from_class)
      @groups_created << @group_created_from_class
    end

    it 'can be done using the user search results curated group selector' do
      @homepage.search test_student.sis_id
      @search_page.selector_add_students_to_new_group([test_student], @group_created_from_search)
      @groups_created << @group_created_from_search
    end
  end

  describe 'curated group names' do

    before(:all) do

      @homepage.load_page

      # Create a filtered cohort to verify that a group cannot have the same name
      filters = CohortFilter.new
      filters.set_custom_filters({:level => ['Freshman (0-29 Units)']})
      @existing_filtered_cohort = FilteredCohort.new({:name => "Existing Filtered Cohort #{test.id}", :search_criteria => filters})
      @curated_page.click_sidebar_create_filtered
      @filtered_page.perform_search(@existing_filtered_cohort, test)
      @filtered_page.create_new_cohort @existing_filtered_cohort

      # Create a curated group to verify that another group cannot have the same name
      @existing_curated_group = CuratedGroup.new({:name => "Existing Curated Group #{test.id}"})
      @student_page.load_page test_student
      @student_page.create_student_curated @existing_curated_group

      # Create and then delete a curated group to verify that another group can have the same name
      @deleted_curated_group = CuratedGroup.new({:name => "Deleted Curated Group #{test.id}"})
      @student_page.create_student_curated @deleted_curated_group
      @curated_page.load_page @deleted_curated_group
      @curated_page.delete_cohort @deleted_curated_group

      @new_curated_group = CuratedGroup.new({})
      @student_page.load_page test_student
    end

    before(:each) { @student_page.cancel_group }

    it 'are required' do
      @student_page.click_create_curated_link
      expect(@student_page.curated_save_button_element.disabled?).to be true
    end

    it 'are truncated to 255 characters' do
      @new_curated_group.name = "#{'A llooooong title ' * 15}?"
      @student_page.click_create_curated_link
      @student_page.enter_group_name @new_curated_group
      expect(@student_page.curated_name_input).to eql(@new_curated_group.name[0..254])
    end

    it 'must not match a non-deleted curated group belonging to the same advisor' do
      @new_curated_group.name = @existing_curated_group.name
      @student_page.click_create_curated_link
      @student_page.name_and_save_group @new_curated_group
      @student_page.dupe_curated_name_msg_element.when_visible Utils.short_wait
    end

    it 'must not match a non-deleted filtered cohort belonging to the same advisor' do
      @new_curated_group.name = @existing_filtered_cohort.name
      @student_page.click_create_curated_link
      @student_page.name_and_save_group @new_curated_group
      @student_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
    end

    it 'can be the same as a deleted group belonging to the same advisor' do
      @new_curated_group.name = @deleted_curated_group.name
      @student_page.click_create_curated_link
      @student_page.name_and_save_group @new_curated_group
      @student_page.wait_for_sidebar_group @new_curated_group
    end

    it 'can be changed' do
      @curated_page.load_page @new_curated_group
      @curated_page.rename_curated(@new_curated_group, "#{@new_curated_group.name} Renamed")
    end
  end

  describe 'curated group membership' do

    before(:all) do
      @student_page.load_page test_student
      advisor_groups.each { |c| @student_page.create_student_curated c }
    end

    it 'can be added from filtered cohort list view using select-all' do
      @filtered_page.load_cohort test.default_cohort
      @filtered_page.selector_add_all_students_to_group(all_students, group_1)
    end

    it 'can be added from filtered cohort list view using individual selections' do
      @filtered_page.load_cohort test.default_cohort
      visible_uids = @filtered_page.list_view_uids
      test.cohort_members = test.cohort_members.select { |m| visible_uids.include? m.uid }
      @filtered_page.selector_add_students_to_group(test.cohort_members[0..-2], group_2)
      test.cohort_members.pop
    end

    it 'can be added on the student page using a curated group box' do
      @student_page.load_page test_student
      @student_page.add_student_to_curated(test_student, group_3)
    end

    it 'can be added on class page list view using select-all' do
      @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      @class_page.selector_add_all_students_to_group(all_students, group_5)
    end

    it 'can be added on class page list view using individual selections' do
      @student_page.load_page test_student
      @student_page.click_class_page_link(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      @class_page.selector_add_students_to_group([test_student], group_6)
    end

    it 'can be added on user search results using select-all' do
      @homepage.search test_student.sis_id
      @search_page.selector_add_all_students_to_curated(all_students, group_7)
    end

    it 'can be added on user search results using individual selections' do
      @homepage.search test_student.sis_id
      @search_page.selector_add_students_to_group([test_student], group_8)
    end

    it 'is shown on the curated group list view page' do
      @curated_page.load_page group_1
      @curated_page.wait_for_student_list
      @curated_page.wait_until(Utils.short_wait, "Expected #{group_1.members.map(&:uid).sort}, but got #{@curated_page.list_view_uids.sort}") do
        @curated_page.list_view_uids.sort == group_1.members.map(&:uid).sort
      end
    end

    it 'is shown on the student page' do
      @student_page.load_page test_student
      @student_page.wait_until(Utils.short_wait) { @student_page.curated_selected? group_3 }
      expect(@student_page.curated_selected? group_4).to be false
    end

    it 'can be removed on the curated group list view page' do
      @curated_page.load_page group_2
      @curated_page.curated_remove_student(group_2.members.last, group_2)
    end

    it 'can be removed on the student page using the curated group checkbox' do
      @student_page.load_page group_1.members.last
      @student_page.remove_student_from_curated(group_1.members.last, group_1)
    end
  end

  describe 'curated groups' do

    it 'can be renamed' do
      @curated_page.load_page advisor_groups.first
      @curated_page.rename_curated(advisor_groups.first, "#{advisor_groups.first.name} Renamed")
    end

    it('allow a deletion to be canceled') { @curated_page.cancel_cohort_deletion advisor_groups.first }

    context 'on the homepage' do

      advisor_groups.each do |group|

        it "shows the curated group named #{group.name}" do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.curated_groups.include? group.name }
        end

        it "shows the curated group #{group.name} membership count" do
          @homepage.wait_until(Utils.short_wait, "Expected #{group.members.length} members, but got #{@homepage.member_count(group)}") { @homepage.member_count(group) == group.members.length }
        end

        it "shows the curated group #{group.name} members with alerts" do
          member_sids = group.members.map &:sis_id
          group.member_data = student_data.select { |data| member_sids.include? data[:sid] }
          @homepage.expand_member_rows group
          @homepage.verify_member_alerts(@driver, group,test.advisor)
        end

      end
    end
  end

  describe 'curated groups' do

    before(:all) do
      @homepage.log_out
      @homepage.dev_auth other_advisor
    end

    it('cannot be seen by a user who does not own them') { expect(@homepage.sidebar_groups & advisor_groups.map(&:name)).to be_empty }

    it 'cannot be reached by a user who does not own them' do
      advisor_groups.each do |c|
        @curated_page.load_page c
        @curated_page.no_group_access_msg(other_advisor, c)
      end
    end

  end
end
