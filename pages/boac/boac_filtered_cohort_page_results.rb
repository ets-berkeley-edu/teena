require_relative '../../util/spec_helper'

module BOACFilteredCohortPageResults

  include PageObject
  include Logging
  include Page

  # Waits for a search to complete and returns the count of results.
  # @return [Integer]
  def wait_for_search_results
    wait_for_spinner
    results_count
  end

  ### GLOBAL FILTERS

  # Returns the student hashes that match a set of entering term filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_entering_term_students(test, search_criteria)
    students = if search_criteria.entering_terms&.any?
                 test.searchable_data.select do |u|
                   search_criteria.entering_terms.find { |search_term| search_term == u[:entering_term] }
                 end
               else
                 test.searchable_data
               end
    students.flatten
  end

  # Returns the student hashes that match a set of expected graduation term filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_grad_term_students(test, search_criteria)
    students = if search_criteria.expected_grad_terms&.any?
                 test.searchable_data.select do |u|
                   search_criteria.expected_grad_terms.find { |search_term| search_term == u[:expected_grad_term] }
                 end
               else
                 test.searchable_data
               end
    students.flatten
  end

  # Returns the student hashes that match a set of GPA filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_gpa_students(test, search_criteria)
    students = []
    if search_criteria.gpa&.any?
      search_criteria.gpa.each do |range|
        low_end = range['min']
        high_end = range['max']
        students << test.searchable_data.select do |u|
          if u[:gpa]
            gpa = u[:gpa].to_f
            gpa >= low_end.to_f && gpa <= high_end.to_f
          end
        end
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  # Returns the student hashes that match a set of level filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_level_students(test, search_criteria)
    if search_criteria.level&.any?
      test.searchable_data.select do |u|
        search_criteria.level.find { |search_level| search_level.include? u[:level] } if u[:level]
      end
    else
      test.searchable_data
    end
  end

  # Returns the student hashes that match a set of major filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_major_students(test, search_criteria)
    students = []
    search_criteria.major&.any? ?
        (students << test.searchable_data.select { |u| (u[:major] & search_criteria.major).any? }) :
        (students = test.searchable_data)
    students.uniq.flatten.compact
  end

  # Returns the student hashes that match a midpoint deficient grade filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_mid_point_students(test, search_criteria)
    search_criteria.mid_point_deficient ? (test.searchable_data.select { |u| u[:mid_point_deficient] }) : test.searchable_data
  end

  # Returns the student hashes that match a transfer student filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_transfer_students(test, search_criteria)
    search_criteria.transfer_student ? (test.searchable_data.select { |u| u[:transfer_student] }) : test.searchable_data
  end

  # Returns the student hashes that match a set of units filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_units_students(test, search_criteria)
    students = []
    if search_criteria.units_completed
      search_criteria.units_completed.each do |units|
        if units.include?('+')
          students << test.searchable_data.select { |u| u[:units_completed].to_f >= 120 if u[:units_completed] }
        else
          range = units.split(' - ')
          low_end = range[0].to_f
          high_end = range[1].to_f
          students << test.searchable_data.select { |u| (u[:units_completed].to_f >= low_end) && (u[:units_completed].to_f < high_end.round(-1)) }
        end
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  # Returns the student hashes that match a last name range filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_last_name_students(test, search_criteria)
    students = []
    if search_criteria.last_name&.any?
      search_criteria.last_name.each do |range|
        low_end = range['min'].downcase
        high_end = range['max'].downcase
        students << test.searchable_data.select do |u|
          u[:last_name_sortable_cohort][0] >= low_end && u[:last_name_sortable_cohort][0] <= high_end
        end
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  # Returns the student hashes that match a set of ethnicity filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_ethnicity_students(test, search_criteria)
    students = []
    (search_criteria.ethnicity&.any?) ?
        (students << test.searchable_data.select { |u| (u[:ethnicity] & search_criteria.ethnicity).any? if u[:ethnicity] }) :
        (students = test.searchable_data)
    students.uniq.flatten.compact
  end

  # Returns the student hashes that match a set of gender filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_gender_students(test, search_criteria)
    students = []
    (search_criteria.gender&.any?) ?
        (students << test.searchable_data.select { |u| search_criteria.gender.include? u[:gender] }) :
        (students = test.searchable_data)
    students.flatten
  end

  # Returns the student hashes that match an underrepresented minority filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_minority_students(test, search_criteria)
    search_criteria.underrepresented_minority ? (test.searchable_data.select { |u| u[:underrepresented_minority] }) : test.searchable_data
  end

  # Returns the student hashes that match a set of academic plan filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_acad_plan_students(test, search_criteria)
    if (plans = search_criteria.cohort_owner_academic_plans) && plans.any?
      test.searchable_data.select do |u|
        u[:advisors].find do |a|
          a[:sid] == @advisor.sis_id && (plans.include?(a['plan_code']) || plans.include?('*'))
        end
      end
    else
      test.searchable_data
    end
  end

  ### ASC-SPECIFIC FILTERS

  # Returns the student hashes that match an ASC inactive filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_asc_inactive_students(test, search_criteria)
    search_criteria.asc_inactive ? (test.searchable_data.reject { |u| u[:asc_active] }) : test.searchable_data
  end

  # Returns the student hashes that match an ASC intensive filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_asc_intensive_students(test, search_criteria)
    search_criteria.asc_intensive ? (test.searchable_data.select { |u| u[:asc_intensive] }) : test.searchable_data
  end

  # Returns the student hashes that match a set of ASC team filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_asc_team_students(test, search_criteria)
    (search_criteria.asc_team&.any?) ?
        (test.searchable_data.select { |u| (u[:asc_sports] & (search_criteria.asc_team.map &:name)).any? }) :
        test.searchable_data
  end

  # COE-SPECIFIC FILTERS

  # Returns the student hashes that match a set of COE advisor filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_advisor_students(test, search_criteria)
    search_criteria.coe_advisor&.any? ? (test.searchable_data.select { |u| search_criteria.coe_advisor.include? u[:coe_advisor] }) : test.searchable_data
  end

  # Returns the student hashes that match a set of COE ethnicity filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_ethnicity_students(test, search_criteria)
    students = []
    if search_criteria.coe_ethnicity&.any?
      search_criteria.coe_ethnicity.each do |coe_ethnicity|
        students << test.searchable_data.select { |u| search_criteria.coe_ethnicity_per_code(u[:coe_ethnicity]) == coe_ethnicity }
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  # Returns the student hashes that match a set of COE gender filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_gender_students(test, search_criteria)
    students = []
    if search_criteria.coe_gender&.any?
      search_criteria.coe_gender.each do |coe_gender|
        if coe_gender == 'Male'
          students << test.searchable_data.select { |u| %w(M m).include? u[:coe_gender] }
        elsif coe_gender == 'Female'
          students << test.searchable_data.select { |u| %w(F f).include? u[:coe_gender] }
        else
          logger.error "Test data has an unrecognized COE gender '#{coe_gender}'"
          fail
        end
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  # Returns the student hashes that match a COE inactive filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_inactive_students(test, search_criteria)
    search_criteria.coe_inactive ? (test.searchable_data.select { |u| u[:coe_inactive] }) : test.searchable_data
  end

  # Returns the student hashes that match a COE underrepresented minority filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_minority_students(test, search_criteria)
    search_criteria.coe_underrepresented_minority ? (test.searchable_data.select { |u| u[:coe_underrepresented_minority] }) : test.searchable_data
  end

  # Returns the student hashes that match a COE probation filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_probation_students(test, search_criteria)
    search_criteria.coe_probation ? (test.searchable_data.select { |u| u[:coe_probation] }) : test.searchable_data
  end

  # Returns the student hashes that match a COE PREP filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_prep_students(test, search_criteria)
    students = []
    if search_criteria.coe_prep&.any?
      search_criteria.coe_prep.each do |prep|
        students << test.searchable_data.select { |u| u[:coe_prep] } if prep == 'PREP'
        students << test.searchable_data.select { |u| u[:prep_elig] } if prep == 'PREP eligible'
        students << test.searchable_data.select { |u| u[:t_prep] } if prep == 'T-PREP'
        students << test.searchable_data.select { |u| u[:t_prep_elig] } if prep == 'T-PREP eligible'
      end
    else
      students = test.searchable_data
    end
    students.flatten
  end

  ### EXPECTED RESULTS

  # Filters an array of user data hashes according to search criteria and returns the users that should be present in the UI after
  # the search completes
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def expected_search_results(test, search_criteria)
    matches = [matching_entering_term_students(test, search_criteria),
               matching_grad_term_students(test, search_criteria),
               matching_gpa_students(test, search_criteria),
               matching_level_students(test, search_criteria),
               matching_major_students(test, search_criteria),
               matching_mid_point_students(test, search_criteria),
               matching_transfer_students(test, search_criteria),
               matching_units_students(test, search_criteria),
               matching_ethnicity_students(test, search_criteria),
               matching_gender_students(test, search_criteria),
               matching_minority_students(test, search_criteria),
               matching_acad_plan_students(test, search_criteria),
               matching_last_name_students(test, search_criteria),
               matching_coe_advisor_students(test, search_criteria),
               matching_coe_ethnicity_students(test, search_criteria),
               matching_coe_gender_students(test, search_criteria),
               matching_coe_inactive_students(test, search_criteria),
               matching_coe_minority_students(test, search_criteria),
               matching_coe_prep_students(test, search_criteria),
               matching_coe_probation_students(test, search_criteria),
               matching_asc_inactive_students(test, search_criteria),
               matching_asc_intensive_students(test, search_criteria),
               matching_asc_team_students(test, search_criteria)]

    matches.any?(&:empty?) ? [] : matches.inject(:'&')
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by first name
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_first_name(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:first_name_sortable_cohort].downcase, u[:last_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by last name
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_last_name(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by team
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_team(expected_results)
    sorted_results = expected_results.sort_by do |u|
      team = u[:squad_names].empty? ? 'zzz' : u[:squad_names].sort.first.gsub(' (AA)', '') .gsub(/\W+/, '')
      [team, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by GPA
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:gpa].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by level
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_level(expected_results)
    # Sort first by the secondary sort order
    results_by_first_name = expected_results.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    # Then arrange by the sort order for level
    results_by_level = []
    %w(Freshman Sophomore Junior Senior Graduate).each do |level|
      results_by_level << results_by_first_name.select do |u|
        u[:level] == level
      end
    end
    results_by_level.flatten.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by major
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_major(expected_results)
    sorted_results = expected_results.sort_by do |u|
      major = u[:major].empty? ? 'aaa' : u[:major].sort.first.gsub(/\W/, '').downcase
      [major, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:units_completed].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

end
