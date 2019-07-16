class CohortFilter

  include Logging

  attr_accessor :gpa,
                :level,
                :units_completed,
                :major,
                :transfer_student,
                :expected_grad_terms,
                :last_name,
                :advisor,
                :coe_ethnicity,
                :coe_gender,
                :underrepresented_minority,
                :prep,
                :inactive_coe,
                :probation_coe,
                :inactive_asc,
                :intensive_asc,
                :team

  # Sets cohort filters based on test data
  # @param test_data [Hash]
  # @param dept [BOACDepartments]
  def set_test_filters(test_data, dept)
    # Global
    @gpa = (test_data['gpa_ranges'] && test_data['gpa_ranges'].map { |g| g['gpa_range'] })
    @level = (test_data['levels'] && test_data['levels'].map { |l| l['level'] })
    @units_completed = (test_data['units'] && test_data['units'].map { |u| u['unit'] })
    @major = (test_data['majors'] && test_data['majors'].map { |t| t['major'] })
    @transfer_student = test_data['transfer_student']
    @expected_grad_terms = (test_data['expected_grad_terms'] && test_data['expected_grad_terms'].map { |t| t['expected_grad_term'] })
    @last_name = test_data['last_initials']

    # CoE
    @advisor = (test_data['advisors'] && test_data['advisors'].map { |a| a['advisor'] })
    @coe_ethnicity = (test_data['coe_ethnicities'] && test_data['coe_ethnicities'].map { |e| coe_ethnicity e['coe_ethnicity'] })
    @coe_gender = (test_data['coe_genders'] && test_data['coe_genders'].map { |g| g['coe_gender'] })
    @underrepresented_minority = test_data['minority']
    @prep = (test_data['preps'] && test_data['preps'].map { |p| p['prep'] })
    @inactive_coe = test_data['inactive_coe']
    @probation_coe = test_data['probation_coe']

    # ASC
    @inactive_asc = test_data['inactive_asc']
    @intensive_asc = test_data['intensive_asc']
    @team = (test_data['teams'] && test_data['teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } })

    # Remove filters that are not available to the department
    if [BOACDepartments::ASC, BOACDepartments::PHYSICS].include? dept
      @advisor = nil
      @coe_ethnicity = nil
      @coe_gender = nil
      @underrepresented_minority = nil
      @prep = nil
      @inactive_coe = nil
      @probation_coe = nil
    end

    if [BOACDepartments::COE, BOACDepartments::PHYSICS].include? dept
      @inactive_asc = nil
      @intensive_asc = nil
      @team = nil
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
  def coe_ethnicity(code)
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
        logger.warn "Unrecognized COE ethnicity '#{code}'" if code && !code.empty? && code != 'Z'
    end
  end

  # Sets cohort filters without using the test data file
  # @param filters_hash [Hash]
  def set_custom_filters(filters_hash)
    filters_hash.each { |k, v| public_send("#{k}=", v) }
  end

end
