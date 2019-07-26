require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  test = BOACTestConfig.new
  test.curated_groups
  test_student = test.cohort_members[1]
  logger.debug "Test student is UID #{test_student.uid} SID #{test_student.sis_id}"

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
    @analytics_page = BOACApiStudentPage.new @driver
    @homepage = BOACHomePage.new @driver
    @group_page = BOACGroupPage.new @driver
    @filtered_page = BOACFilteredCohortPage.new(@driver, test.advisor)
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

  it 'groups can all be deleted' do
    pre_existing_groups.each do |c|
      @group_page.load_page c
      @group_page.delete_cohort c
    end
  end

  describe 'group creation' do

    it 'can be done using the filtered cohort list view group selector' do
      @filtered_page.load_cohort test.default_cohort
      @filtered_page.wait_for_student_list
      sids = @filtered_page.list_view_sids
      visible_members = test.students.select { |m| sids.include? m.sis_id }
      group_created_from_filter = CuratedGroup.new({:name => "Group created from filtered cohort #{test.id}"})
      @filtered_page.select_and_add_students_to_new_grp(visible_members, group_created_from_filter)
    end

    it 'can be done using the class page list view group selector' do
      @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      sids = @class_page.class_list_view_sids
      visible_members = test.students.select { |m| sids.include? m.sis_id }
      group_created_from_class = CuratedGroup.new({:name => "Group created from class page #{test.id}"})
      @class_page.select_and_add_students_to_new_grp(visible_members, group_created_from_class)
    end

    it 'can be done using the user search results group selector' do
      @homepage.search_non_note test_student.sis_id
      group_created_from_search = CuratedGroup.new({:name => "Group created from search results #{test.id}"})
      @search_page.select_and_add_students_to_new_grp([test_student], group_created_from_search)
    end

    it 'can be done using the student page group selector' do
      @student_page.load_page test_student
      group_created_from_profile = CuratedGroup.new({:name => "Group created from student page #{test.id}"})
      @student_page.add_student_to_new_grp(test_student, group_created_from_profile)
    end

    it 'can be done using bulk SIDs feature' do
      students = test.students.first(10)
      @homepage.click_sidebar_create_curated_group
      group_created_from_bulk = CuratedGroup.new({:name => "Group created with bulk SIDs #{test.id}"})
      @group_page.create_group_with_bulk_sids(students, group_created_from_bulk)
      @group_page.wait_for_sidebar_group group_created_from_bulk
    end
  end

  describe 'group names' do

    before(:all) do

      @homepage.load_page

      # Create a filtered cohort to verify that a group cannot have the same name
      filters = CohortFilter.new
      filters.set_custom_filters({:level => ['Freshman (0-29 Units)']})
      @existing_filtered_cohort = FilteredCohort.new({:name => "Existing Filtered Cohort #{test.id}", :search_criteria => filters})
      @group_page.click_sidebar_create_filtered
      @filtered_page.perform_search(@existing_filtered_cohort, test)
      @filtered_page.create_new_cohort @existing_filtered_cohort

      # Create a curated group to verify that another group cannot have the same name
      @existing_group = CuratedGroup.new({:name => "Existing Group #{test.id}"})
      @student_page.load_page test_student
      @student_page.add_student_to_new_grp(test_student, @existing_group)

      # Create and then delete a curated group to verify that another group can have the same name
      @deleted_group = CuratedGroup.new({:name => "Deleted Group #{test.id}"})
      @student_page.add_student_to_new_grp(test_student, @deleted_group)
      @group_page.load_page @deleted_group
      @group_page.delete_cohort @deleted_group

      @new_group = CuratedGroup.new({})
      @student_page.load_page test_student
    end

    before(:each) { @student_page.cancel_group if @student_page.grp_cancel_button_element.visible? }

    it 'are required' do
      @student_page.click_add_to_grp_button
      @student_page.click_create_new_grp
      expect(@student_page.grp_save_button_element.disabled?).to be true
    end

    it 'are truncated to 255 characters' do
      @new_group.name = "#{'A llooooong title ' * 15}?"
      @student_page.click_add_to_grp_button
      @student_page.click_create_new_grp
      @student_page.enter_group_name @new_group
      expect(@student_page.grp_name_input).to eql(@new_group.name[0..254])
    end

    it 'must not match a non-deleted group belonging to the same advisor' do
      @new_group.name = @existing_group.name
      @student_page.click_add_to_grp_button
      @student_page.click_create_new_grp
      @student_page.name_and_save_group @new_group
      @student_page.dupe_grp_name_msg_element.when_visible Utils.short_wait
    end

    it 'must not match a non-deleted filtered cohort belonging to the same advisor' do
      @new_group.name = @existing_filtered_cohort.name
      @student_page.click_add_to_grp_button
      @student_page.click_create_new_grp
      @student_page.name_and_save_group @new_group
      @student_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
    end

    it 'can be the same as a deleted group belonging to the same advisor' do
      @new_group.name = @deleted_group.name
      @student_page.add_student_to_new_grp(test_student, @new_group)
    end

    it 'can be changed' do
      @group_page.load_page @new_group
      @group_page.rename_grp(@new_group, "#{@new_group.name} Renamed")
    end
  end

  describe 'group membership' do

    before(:all) do
      student = test.cohort_members.last
      test.cohort_members.pop
      @student_page.load_page student
      advisor_groups.each { |c| @student_page.add_student_to_new_grp(student, c) }
    end

    it 'can be added from filtered cohort list view using select-all' do
      @filtered_page.load_cohort test.default_cohort
      @filtered_page.select_and_add_all_students_to_grp(test.students, group_1)
      @group_page.load_page group_1
      expect(@group_page.visible_sids.sort).to eql(group_1.members.map(&:sis_id).sort)
    end

    it 'can be added from filtered cohort list view using individual selections' do
      @filtered_page.load_cohort test.default_cohort
      group_uids = group_2.members.map &:uid
      visible_uids = @filtered_page.list_view_uids - group_uids
      test.cohort_members = test.cohort_members.select { |m| visible_uids.include? m.uid }
      @filtered_page.select_and_add_students_to_grp(test.cohort_members[0..-2], group_2)
      @group_page.load_page group_2
      expect(@group_page.visible_sids.sort).to eql(group_2.members.map(&:sis_id).sort)
      test.cohort_members.pop
    end

    it 'can be added on the student page' do
      @student_page.load_page test_student
      @student_page.add_student_to_grp(test_student, group_3)
      @group_page.load_page group_3
      expect(@group_page.visible_sids.sort).to eql(group_3.members.map(&:sis_id).sort)
    end

    it 'can be added on the bulk-add-SIDs page' do
      @group_page.load_page group_4
      @group_page.add_sids_to_existing_grp(test.students.last(10), group_4)
      missing_sids = group_4.members.map(&:sis_id).sort - @group_page.visible_sids.sort
      # Account for SIDs that have no associated data and will not appear in Boa
      if missing_sids.any?
        missing_sids.each do |missing_sid|
          logger.info "Checking data for missing SID '#{missing_sid}'"
          student = group_4.members.find { |s| s.sis_id == missing_sid }
          api_data = @analytics_page.get_data(@driver, student)
          unless api_data
            logger.info "Removing SID #{missing_sid} from the group since the student does not appear in Boa"
            missing_sids.delete missing_sid
            group_4.members.delete student
          end
        end
      end
      expect(missing_sids).to be_empty
    end

    it 'can be added on class page list view using select-all' do
      @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      @class_page.select_and_add_all_students_to_grp(test.students, group_5)
      @group_page.load_page group_5
      expect(@group_page.visible_sids.sort).to eql(group_5.members.map(&:sis_id).sort)
    end

    it 'can be added on class page list view using individual selections' do
      @student_page.load_page test_student
      @student_page.click_class_page_link(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
      @class_page.select_and_add_students_to_grp([test_student], group_6)
      @group_page.load_page group_6
      expect(@group_page.visible_sids.sort).to eql(group_3.members.map(&:sis_id).sort)
    end

    it 'can be added on user search results using select-all' do
      @homepage.search_non_note test_student.sis_id
      @search_page.select_and_add_all_students_to_grp(test.students, group_7)
      @group_page.load_page group_7
      expect(@group_page.visible_sids.sort).to eql(group_7.members.map(&:sis_id).sort)
    end

    it 'can be added on user search results using individual selections' do
      @homepage.search_non_note test_student.sis_id
      @search_page.select_and_add_students_to_grp([test_student], group_8)
      @group_page.load_page group_8
      expect(@group_page.visible_sids.sort).to eql(group_8.members.map(&:sis_id).sort)
    end

    it 'is shown on the student page' do
      @student_page.load_page group_1.members.first
      @student_page.click_add_to_grp_button
      expect(@student_page.grp_selected? group_1).to be true
    end

    it 'can be removed on the group list view page' do
      @group_page.load_page group_2
      student = group_2.members.last
      logger.info "Removing UID #{student.uid} from group '#{group_2.name}'"
      @group_page.remove_student_by_row_index(group_2, student)
      expect(@group_page.visible_sids.sort).to eql(group_2.members.map(&:sis_id).sort)
    end

    it 'can be removed on the student page using the group checkbox' do
      @student_page.load_page group_1.members.last
      @student_page.remove_student_from_grp(group_1.members.last, group_1)
      @group_page.load_page group_1
      expect(@group_page.visible_sids.sort).to eql(group_1.members.map(&:sis_id).sort)
    end
  end

  describe 'group bulk-add SIDs' do

    before(:each) { @group_page.load_page group_4 }

    it 'rejects malformed input' do
      @group_page.click_add_students_button
      @group_page.enter_sid_list 'nullum magnum ingenium sine mixtura dementiae fuit'
      @group_page.click_add_sids_to_group_button
      @group_page.sids_bad_format_error_msg_element.when_visible Utils.short_wait
    end

    it 'rejects SIDs that do not match any Boa student SIDs' do
      @group_page.click_add_students_button
      @group_page.enter_sid_list '9999999990, 9999999991'
      @group_page.click_add_sids_to_group_button
      @group_page.sids_not_found_error_msg_element.when_visible Utils.short_wait
    end

    it 'allows the user to add large sets of SIDs' do
      @group_page.add_sids_to_existing_grp(test.students.first(BOACUtils.group_bulk_sids_max), group_4)
      @group_page.wait_for_list_to_load
      missing_sids = group_4.members.map(&:sis_id).sort - @group_page.visible_sids.sort
      # Account for SIDs that have no associated data and will not appear in Boa
      if missing_sids.any?
        missing_sids.each do |missing_sid|
          logger.info "Checking data for missing SID '#{missing_sid}'"
          student = group_4.members.find { |s| s.sis_id == missing_sid }
          api_data = @analytics_page.get_data(@driver, student)
          unless api_data
            logger.info "Removing SID #{missing_sid} from the group since the student does not appear in Boa"
            missing_sids.delete missing_sid
            group_4.members.delete student
          end
        end
      end
      expect(missing_sids).to be_empty
    end
  end

  describe 'groups' do

    it 'can be renamed' do
      @group_page.load_page advisor_groups.first
      @group_page.rename_grp(advisor_groups.first, "#{advisor_groups.first.name} Renamed")
    end

    it('allow a deletion to be canceled') { @group_page.cancel_cohort_deletion advisor_groups.first }

    context 'on the homepage' do

      advisor_groups.each do |group|

        it "shows the group named #{group.name}" do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.curated_groups.include? group.name }
        end

        it "shows the group #{group.name} membership count" do
          @homepage.wait_until(Utils.short_wait, "Expected #{group.members.length} members, but got #{@homepage.member_count(group)}") { @homepage.member_count(group) == group.members.length }
        end

        it "shows the group #{group.name} members with alerts" do
          member_sids = group.members.map &:sis_id
          group.member_data = test.searchable_data.select { |data| member_sids.include? data[:sid] }
          @homepage.expand_member_rows group
          @homepage.verify_member_alerts(@driver, group,test.advisor)
        end

      end
    end
  end

  describe 'group membership' do

    advisor_groups.each do |group|

      it "can be exported for group #{group.name}" do
        @group_page.load_page group
        csv = @group_page.export_student_list group
        @group_page.verify_student_list_export(group.members, csv)
      end
    end
  end

  describe 'groups' do

    before(:all) do
      @homepage.log_out
      @homepage.dev_auth other_advisor
    end

    it('cannot be seen by a user who does not own them') { expect(@homepage.sidebar_groups & advisor_groups.map(&:name)).to be_empty }

    it 'cannot be reached by a user who does not own them' do
      advisor_groups.each do |c|
        @group_page.load_page c
        @group_page.no_group_access_msg(other_advisor, c)
      end
    end

  end
end
