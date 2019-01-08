class BOACTestConfig < TestConfig

  include Logging

  attr_accessor :dept, :advisor, :term, :dept_students, :searches, :default_cohort, :cohort_members, :max_cohort_members

  CONFIG = BOACUtils.config

  # Basic settings for department, advisor, and student population under test. Specifying a department will override the
  # department in the settings file.
  # @param all_students [Array<BOACUser>]
  # @param dept [BOACDepartments]
  def set_global_configs(all_students, dept = nil)
    @dept = dept ? dept : (BOACDepartments::DEPARTMENTS.find { |d| d.code == CONFIG['test_dept'] })
    advisors = BOACUtils.get_dept_advisors @dept

    case @dept
      when BOACDepartments::ADMIN
        @advisor = BOACUser.new({:uid => Utils.super_admin_uid})
      when BOACDepartments::ASC
        @advisor = advisors.first
      when BOACDepartments::COE
        uid = CONFIG['test_coe_advisor_uid']
        @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.first
      else
        logger.error 'What kinda department is that??'
        fail
    end

    # Admin should see all students; departments should see only their own students.
    @dept_students = if @dept == BOACDepartments::ADMIN
                       all_students
                     else
                       all_students.select do |s|
                         (s.depts.select { |d| d == @dept }).any?
                       end
                     end
  end

  # Sets an existing cohort to use for testing, e.g., a team for ASC and admin or My Students for CoE
  # @param team_config [String]
  def set_default_cohort(team_config)
    case @dept
      # For CoE, use the advisor's assigned students
      when BOACDepartments::COE
        filter = CohortFilter.new
        filter.advisor = [@advisor.uid]
        @default_cohort = FilteredCohort.new({:search_criteria => filter})
        @cohort_members = NessieUtils.get_coe_advisor_students(@advisor, @dept_students)
      # For ASC or admin, use a team
      else
        team = NessieUtils.get_asc_teams.find { |t| t.code == team_config }
        filter = CohortFilter.new
        filter.team = Squad::SQUADS.select { |s| s.parent_team == team }
        @default_cohort = FilteredCohort.new({:search_criteria => filter})
        @cohort_members = NessieUtils.get_asc_team_members(team, @dept_students)
    end

    @default_cohort.name = "Default cohort #{@id}"
    @default_cohort.member_count = @cohort_members.length
    @term = BOACUtils.assignments_term
  end

  # Selects only the first n cohort members for testing
  # @param config [Integer]
  def set_max_cohort_members(config)
    @max_cohort_members = @cohort_members.sort_by(&:last_name)[0..(config - 1)]
  end

  # Configures a set of cohorts to use for filtered cohort testing
  def set_search_cohorts
    test_data_file = File.join(Utils.config_dir, 'test-data-boac.json')
    test_data = JSON.parse File.read(test_data_file)
    filters = test_data['filters'].map do |data|
      filter = CohortFilter.new
      filter.set_test_filters(data, @dept)
      filter
    end
    # Get rid of empty filter sets (e.g., filtering only for teams but the advisor is CoE)
    filters.delete_if do |f|
      filter_options = f.instance_variables.map { |variable| f.instance_variable_get variable }
      filter_options.delete_if { |value| value.nil? || (value.instance_of?(Array) && value.empty?) }
      filter_options.empty?
    end
    @searches = filters.map { |c| FilteredCohort.new({:name => "Test Cohort #{filters.index c} #{@id}", :search_criteria => c}) }
  end

  # Config for assignments testing
  # @param all_students [Array<BOACUser>]
  def assignments(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['assignments_team']
    set_max_cohort_members CONFIG['assignments_max_users']
  end

  # Config for class page testing
  # @param all_students [Array<BOACUser>]
  def class_pages(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['class_page_team']
    set_max_cohort_members CONFIG['class_page_max_users']
  end

  # Config for curated group testing
  # @param all_students [Array<BOACUser>]
  def curated_groups(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['curated_group_team']
    @cohort_members.keep_if &:active_asc if @dept == BOACDepartments::ASC
    set_max_cohort_members 50
  end

  # Config for filtered cohort testing
  # @param all_students [Array<BOACUser>]
  def filtered_cohorts(all_students)
    set_global_configs all_students
    set_search_cohorts

    # Set a default cohort with all possible filters to exercise editing and removing filters
    filters = {
      :gpa => ['3.00 - 3.49'],
      :level => ['Senior (90+ Units)'],
      :units_completed => ['90 - 119'],
      :major => ['Electrical Eng & Comp Sci BS'],
      :last_name => 'AZ',
      :advisor => ([BOACUtils.get_dept_advisors(BOACDepartments::COE).first.uid.to_s] unless @dept == BOACDepartments::ASC),
      :ethnicity => (['Chinese / Chinese-American'] unless @dept == BOACDepartments::ASC),
      :gender => (['Female'] unless @dept == BOACDepartments::ASC),
      :underrepresented_minority => (true unless @dept == BOACDepartments::ASC),
      :prep => (['PREP'] unless @dept == BOACDepartments::ASC),
      :inactive_coe => (true unless @dept == BOACDepartments::ASC),
      :probation_coe => (true unless @dept == BOACDepartments::ASC),
      :inactive_asc => (true unless @dept == BOACDepartments::COE),
      :intensive_asc => (true unless @dept == BOACDepartments::COE),
      :team => ([Squad::MCR] unless @dept == BOACDepartments::COE)
    }
    editing_test_search_criteria = CohortFilter.new
    editing_test_search_criteria.set_custom_filters(filters)
    @default_cohort = FilteredCohort.new({:name => "Default cohort #{@id}", :search_criteria => editing_test_search_criteria})
  end

  # Config for last activity testing
  # @param all_students [Array<BOACUser>]
  def last_activity(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['last_activity_team']
    set_max_cohort_members CONFIG['last_activity_max_users']
  end

  # Config for page navigation testing
  # @param all_students [Array<BOACUser>]
  def navigation(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['class_page_team']
    set_max_cohort_members CONFIG['class_page_max_users']
  end

  # Config for SIS data testing
  # @param all_students [Array<BOACUser>]
  def sis_data(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['sis_data_team']
    @cohort_members.keep_if &:active_asc if @dept == BOACDepartments::ASC
    set_max_cohort_members CONFIG['sis_data_max_users']
  end

  # Config for admin user role testing
  # @param all_students [Array<BOACUser>]
  def user_role_admin(all_students)
    set_global_configs(all_students, BOACDepartments::ADMIN)
    set_search_cohorts
  end

  # Config for ASC user role testing
  # @param all_students [Array<BOACUser>]
  def user_role_asc(all_students)
    set_global_configs(all_students, BOACDepartments::ASC)
    set_search_cohorts
  end

  # Config for CoE user role testing
  # @param all_students [Array<BOACUser>]
  def user_role_coe(all_students)
    set_global_configs(all_students, BOACDepartments::COE)
    set_default_cohort nil
    set_search_cohorts
  end

  # Config for user search testing
  # @param all_students [Array<BOACUser>]
  def user_search(all_students)
    set_global_configs all_students
    set_default_cohort CONFIG['user_search_team']
    @cohort_members.keep_if &:active_asc if @dept == BOACDepartments::ASC
    set_max_cohort_members CONFIG['user_search_max_users']
  end

  # Uses the secondary Chrome profile if config set to true
  def chrome_profile
    if Utils.use_optional_chrome_profile?
      logger.warn 'Using the secondary Chrome profile'
      Utils.optional_chrome_profile_dir
    end
  end

end
