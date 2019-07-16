class BOACTestConfig < TestConfig

  include Logging

  CONFIG = BOACUtils.config

  attr_accessor :advisor,
                :attachments,
                :cohort_members,
                :default_cohort,
                :dept,
                :dept_students,
                :max_cohort_members,
                :searchable_data,
                :searches,
                :students,
                :term

  # If a test requires a specific dept, sets that one. Otherwise, sets the globally configured dept.
  # @param dept [BOACDepartments]
  def set_dept(dept)
    @dept = dept ? dept : (BOACDepartments::DEPARTMENTS.find { |d| d.code == CONFIG['test_dept'] })
  end

  # Sets the advisor to use for the dept being tested
  def set_advisor
    advisors = BOACUtils.get_dept_advisors @dept
    case @dept
      when BOACDepartments::ADMIN
        @advisor = BOACUser.new({:uid => Utils.super_admin_uid})
      when BOACDepartments::ASC
        @advisor = advisors.first
      when BOACDepartments::COE
        uid = CONFIG['test_coe_advisor_uid']
        @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.first
      when BOACDepartments::L_AND_S
        uid = CONFIG['test_l_and_s_advisor_uid']
        @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.first
      when BOACDepartments::PHYSICS
        @advisor = advisors.first
      else
        logger.error 'What kinda department is that??'
        fail
    end
    logger.warn "Advisor is UID #{@advisor.uid}"
  end

  # Sets the complete list of potentially visible students
  def set_students
    @students = NessieUtils.get_all_students
  end

  # Sets the list of students belonging to the department in question (not relevant to admins)
  # @param dept [BOACDepartments]
  def set_dept_students(dept=nil)
    dept = dept || @dept
    @dept_students = if dept == BOACDepartments::ADMIN
                       []
                     else
                       @students.select do |s|
                         # Some students belong to multiple depts
                         (s.depts.select { |d| d == dept }).any?
                       end
                     end
  end

  # Returns all searchable student data. Unless a current file containing all student data already exists, obtain
  # the current data from Redshift.
  # @param all_students [Array<BOACUser>]
  # @return [Array<Hash>]
  def set_student_searchable_data(all_students)
    # Get the searchable data for all students.
    student_sids = @students.map &:sis_id
    @searchable_data = NessieUtils.searchable_student_data(all_students).select { |u| student_sids.include? u[:sid] }
  end

  # Basic settings for department, advisor, and student population under test. Specifying a department will override the
  # department in the settings file.
  # @param dept [BOACDepartments]
  def set_global_configs(dept = nil)
    set_dept dept
    set_advisor
    set_students
    set_dept_students dept
    set_student_searchable_data @students
  end

  # Sets a cohort to use as a default group of students for testing, e.g., a team for ASC and admin or My Students for CoE
  def set_default_cohort
    @default_cohort = FilteredCohort.new({})
    filter = CohortFilter.new

    case @dept
      # For CoE, use the advisor's assigned students
      when BOACDepartments::COE
        filter.advisor = [@advisor.uid]
        @default_cohort.search_criteria = filter
        @cohort_members = NessieUtils.get_coe_advisor_students(@advisor, @students)

      # For L&S, use students of configured major
      when BOACDepartments::L_AND_S
        filter.major = CONFIG['test_l_and_s_major']
        @default_cohort.search_criteria = filter
        student_sids = @students.map &:sis_id
        filtered_searchable_data = @searchable_data.select { |d| (filter.major & d[:major]).any? }
        filtered_searchable_sids = filtered_searchable_data.map { |d| d[:sid] }
        @cohort_members = @students.select { |s| student_sids.include?(s.sis_id) && filtered_searchable_sids.include?(s.sis_id) }

      # For Physics, use students of configured levels
      when BOACDepartments::PHYSICS
        filter.level = CONFIG['test_physics_levels']
        @default_cohort.search_criteria = filter
        student_sids = @students.map &:sis_id
        filtered_searchable_data = @searchable_data.select { |d| filter.level.include?(d[:level]) }
        filtered_searchable_sids = filtered_searchable_data.map { |d| d[:sid] }
        @cohort_members = @students.select { |s| student_sids.include?(s.sis_id) && filtered_searchable_sids.include?(s.sis_id) }

      # For ASC or admin, use a team
      else
        team = NessieUtils.get_asc_teams.find { |t| t.code == CONFIG['test_asc_team'] }
        filter.team = Squad::SQUADS.select { |s| s.parent_team == team }
        @default_cohort.search_criteria = filter
        @cohort_members = NessieUtils.get_asc_team_members(team, @students)
    end

    @default_cohort.name = "Default cohort #{@id}"
    @default_cohort.member_count = @cohort_members.length
  end

  # Selects only the first n cohort members for testing
  # @param config [Integer]
  def set_max_cohort_members(config)
    @max_cohort_members = @cohort_members.sort_by(&:last_name)[0..(config - 1)]
  end

  # Configures a set of cohorts to use for filtered cohort testing. If a test data override file exists in the config override dir,
  # then uses that to create the filters. Otherwise, uses the default test data.
  def set_search_cohorts

    # Because its student population dwarfs the others', L&S has its own cohort test data file
    test_data_file_name = (@dept == BOACDepartments::L_AND_S) ? 'test-data-boac-l-and-s.json' : 'test-data-boac.json'
    override_test_data = File.exist? (override_path = File.join(Utils.config_dir, test_data_file_name))
    test_data_file = override_test_data ? override_path : File.expand_path("test_data/#{test_data_file_name}", Dir.pwd)
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

  # Uses the secondary Chrome profile if config set to true
  # @return [String]
  def chrome_profile
    if Utils.use_optional_chrome_profile?
      logger.warn 'Using the secondary Chrome profile'
      Utils.optional_chrome_profile_dir
    end
  end


  ### CONFIGURATION FOR SPECIFIC TEST SCRIPTS ###

  # Config for assignments testing
  def assignments
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['assignments_max_users']
    @term = CONFIG['assignments_term']
  end

  # Config for class page testing
  def class_pages
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['class_page_max_users']
  end

  # Config for curated group testing
  def curated_groups
    set_global_configs
    set_default_cohort
    @cohort_members.keep_if &:active_asc if @dept == BOACDepartments::ASC
    set_max_cohort_members 50
  end

  # Config for filtered cohort testing
  def filtered_cohorts
    set_global_configs
    set_search_cohorts

    # Set a default cohort with all possible filters to exercise editing and removing filters
    major = case @dept
              when BOACDepartments::COE
                ['Electrical Eng & Comp Sci BS']
              when BOACDepartments::PHYSICS
                ['Physics']
              else
                ['Letters & Sci Undeclared UG']
            end
    filters = {
      :gpa => ['3.00 - 3.49'],
      :level => ['Senior (90+ Units)'],
      :units_completed => ['90 - 119'],
      :major => major,
      :transfer_student => true,
      :expected_grad_terms => [CONFIG['term_code']],
      :last_name => 'A Z',
    }

    if [BOACDepartments::ASC, BOACDepartments::ADMIN].include? @dept
      filters.merge!({
                         :inactive_asc => true,
                         :intensive_asc => true,
                         :team => [Squad::MCR]
                    })
    end

    if [BOACDepartments::COE, BOACDepartments::ADMIN].include? @dept
      filters.merge!({
                         :advisor => [BOACUtils.get_dept_advisors(BOACDepartments::COE).first.uid.to_s],
                         :coe_ethnicity => ['Chinese / Chinese-American'],
                         :coe_gender => ['Female'],
                         :underrepresented_minority => true,
                         :prep => ['PREP'],
                         :inactive_coe => true,
                         :probation_coe => true
                     })
    end

    editing_test_search_criteria = CohortFilter.new
    editing_test_search_criteria.set_custom_filters(filters)
    @default_cohort = FilteredCohort.new({:name => "Default cohort #{@id}", :search_criteria => editing_test_search_criteria})
  end

  # Config for last activity testing
  def last_activity
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['last_activity_max_users']
  end

  # Config for legacy advising notes testing
  def legacy_notes
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['legacy_notes_max_users']
  end

  # Config for page navigation testing
  def navigation
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['class_page_max_users']
  end

  # Config for note management testing (create, edit, delete)
  def note_management
    attachment_filenames = Dir.entries(Utils.assets_dir).reject { |f| %w(. .. .DS_Store).include? f }
    @attachments = attachment_filenames.map do |f|
      file = File.new Utils.asset_file_path(f)
      Attachment.new({:file_name => f, :file_size => file.size})
    end
    set_global_configs
  end

  # Config for testing batch note creation
  def batch_note_management
    attachment_filenames = Dir.entries(Utils.assets_dir).reject { |f| %w(. .. .DS_Store).include? f }
    @attachments = attachment_filenames.map do |f|
      file = File.new Utils.asset_file_path(f)
      Attachment.new({:file_name => f, :file_size => file.size})
    end
    set_global_configs
    set_default_cohort
  end

  # Config for user search testing
  def search
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['search_max_users']
  end

  # Config for SIS data testing
  def sis_data
    set_global_configs
    set_default_cohort
    set_max_cohort_members CONFIG['sis_data_max_users']
  end

  # Config for admin user role testing
  def user_role_admin
    set_global_configs BOACDepartments::ADMIN
    set_search_cohorts
  end

  # Config for ASC user role testing
  def user_role_asc
    set_global_configs BOACDepartments::ASC
    set_search_cohorts
  end

  # Config for CoE user role testing
  def user_role_coe
    set_global_configs BOACDepartments::COE
    set_default_cohort
    set_search_cohorts
  end

  # Config for L&S user role testing
  def user_role_l_and_s
    set_global_configs BOACDepartments::L_AND_S
    set_default_cohort
    set_search_cohorts
  end

  # Config for Physics user role testing
  def user_role_physics
    set_global_configs BOACDepartments::PHYSICS
    set_search_cohorts
  end

end
