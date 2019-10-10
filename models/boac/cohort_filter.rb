class CohortFilter

  include Logging

  attr_accessor :asc_inactive,
                :asc_intensive,
                :asc_team,
                :coe_advisor,
                :coe_ethnicity,
                :coe_gender,
                :coe_inactive,
                :coe_prep,
                :coe_probation,
                :coe_underrepresented_minority,
                :cohort_owner_academic_plans,
                :entering_terms,
                :ethnicity,
                :expected_grad_terms,
                :gender,
                :gpa,
                :last_name,
                :level,
                :major,
                :mid_point_deficient,
                :transfer_student,
                :underrepresented_minority,
                :units_completed


  # Sets cohort filters based on test data
  # @param test_data [Hash]
  # @param dept [BOACDepartments]
  def set_test_filters(test_data, dept)
    # Global
    @entering_terms = (test_data['entering_terms'] && test_data['entering_terms'].map { |t| t['entering_term'] })
    @expected_grad_terms = (test_data['expected_grad_terms'] && test_data['expected_grad_terms'].map { |t| t['expected_grad_term'] })
    @gpa = (test_data['gpa_ranges'] && test_data['gpa_ranges'].map { |g| g['gpa_range'] })
    @level = (test_data['levels'] && test_data['levels'].map { |l| l['level'] })
    @major = (test_data['majors'] && test_data['majors'].map { |t| t['major'] })
    @mid_point_deficient = test_data['mid_point_deficient']
    @transfer_student = test_data['transfer_student']
    @units_completed = (test_data['units'] && test_data['units'].map { |u| u['unit'] })

    @ethnicity = (test_data['ethnicities'] && test_data['ethnicities'].map { |e| e['ethnicity'] })
    @gender = (test_data['genders'] && test_data['genders'].map { |g| g['gender'] })
    @underrepresented_minority = test_data['underrepresented_minority']
    @last_name = (test_data['last_initials'] && test_data['last_initials'].map { |l| l['last_initial'] })

    # My Students
    @cohort_owner_academic_plans = (test_data['cohort_owner_academic_plans'] && test_data['cohort_owner_academic_plans'].map { |t| t['plan'] })

    # CoE
    @coe_advisor = (test_data['coe_advisors'] && test_data['coe_advisors'].map { |a| a['advisor'] })
    @coe_ethnicity = (test_data['coe_ethnicities'] && test_data['coe_ethnicities'].map { |e| coe_ethnicity_per_code e['ethnicity'] })
    @coe_gender = (test_data['coe_genders'] && test_data['coe_genders'].map { |g| g['gender'] })
    @coe_inactive = test_data['coe_inactive']
    @coe_prep = (test_data['coe_preps'] && test_data['coe_preps'].map { |p| p['prep'] })
    @coe_probation = test_data['coe_probation']
    @coe_underrepresented_minority = test_data['coe_underrepresented_minority']

    # ASC
    @asc_inactive = test_data['asc_inactive']
    @asc_intensive = test_data['asc_intensive']
    @asc_team = (test_data['asc_teams'] && test_data['asc_teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } })

    # Remove filters that are not available to the department
    unless [BOACDepartments::ADMIN, BOACDepartments::COE].include? dept
      @coe_advisor = nil
      @coe_ethnicity = nil
      @coe_gender = nil
      @coe_underrepresented_minority = nil
      @coe_prep = nil
      @coe_inactive = nil
      @coe_probation = nil
    end

    unless [BOACDepartments::ADMIN, BOACDepartments::ASC].include? dept
      @asc_inactive = nil
      @asc_intensive = nil
      @asc_team = nil
    end
  end

  # Returns the array of filter values
  # @return [Array<Object>]
  def list_filters
    instance_variables.map { |variable| instance_variable_get variable }
  end

  # CoE ethnicity code translations
  # @param code [String]
  # @return [String]
  def coe_ethnicity_per_code(code)
    case code
      when 'A'
        'African-American / Black'
      when 'B'
        'Japanese / Japanese-American'
      when 'C'
        'American Indian / Alaska Native'
      when 'D'
        'Other'
      when 'E'
        'Mexican / Mexican-American / Chicano'
      when 'F'
        'White / Caucasian'
      when 'G'
        'Declined to state'
      when 'H'
        'Chinese / Chinese-American'
      when 'I'
        'Other Spanish-American / Latino'
      when 'L'
        'Filipino / Filipino-American'
      when 'M'
        'Pacific Islander'
      when 'P'
        'Puerto Rican'
      when 'R'
        'East Indian / Pakistani'
      when 'T'
        'Thai / Other Asian'
      when 'V'
        'Vietnamese'
      when 'X'
        'Korean / Korean-American'
      when 'Y'
        'Other Asian'
      else
        logger.warn "Unrecognized Ethnicity (COE): '#{code}'" if code && !code.empty? && code != 'Z'
    end
  end

  # Sets cohort filters without using the test data file
  # @param filters_hash [Hash]
  def set_custom_filters(filters_hash)
    filters_hash.each { |k, v| public_send("#{k}=", v) }
  end

end
