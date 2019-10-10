require_relative '../../util/spec_helper'

module BOACFilteredCohortPageFilters

  include PageObject
  include Logging
  include Page

  # NEW FILTERED COHORTS

  button(:new_filter_button, xpath: '//button[starts-with(@id, \'new-filter-button\')]')
  button(:new_sub_filter_button, xpath: '//div[contains(@id,"filter-row-dropdown-secondary")]//button')
  elements(:new_filter_option, :link, class: 'dropdown-item')
  text_field(:filter_range_min_input, id: 'filter-range-min')
  text_field(:filter_range_max_input, id: 'filter-range-max')
  button(:unsaved_filter_add_button, id: 'unsaved-filter-add')
  button(:unsaved_filter_cancel_button, id: 'unsaved-filter-reset')
  button(:unsaved_filter_apply_button, id: 'unsaved-filter-apply')

  # Clicks the new filter button, making two attempts in case of a DOM update
  def click_new_filter_button
    wait_for_update_and_click new_filter_button_element
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    wait_for_update_and_click new_filter_button_element
  end

  # Returns a filter option link with the given filter key text as part of the link element id.
  # @param filter_key [String]
  # @return [PageObject::Elements::Link]
  def new_filter_option(filter_key)
    link_element(id: "dropdown-primary-menuitem-#{filter_key}-new")
  end

  # Returns the Choose button for a new filter sub-option
  # @return [PageObject::Elements::Button]
  def new_filter_sub_option_button
    button_element(xpath: '//button[contains(., "Choose...")]')
  end

  # Returns the sub-option link for a new filter
  # @param [String] filter_key
  # @param [String] filter_option
  # @return [PageObject::Elements::Link]
  def new_filter_sub_option_element(filter_key, filter_option)
    case filter_key
      when 'enteringTerms'
        link_element(id: "Entering Term-#{filter_option}")
      when 'expectedGradTerms'
        link_element(id: "Expected Graduation Term-#{filter_option}")
      when 'coeAdvisorLdapUids'
        link_element(id: "Advisor (COE)-#{filter_option}")
      when 'majors'
        link_element(id: "Major-#{filter_option}")
      when 'cohortOwnerAcademicPlans'
        link_element(id: "My Students-#{filter_option}")
      else
        link_element(xpath: "//div[@class=\"filter-row-column-02 mt-1\"]//a[contains(.,\"#{filter_option}\")]")
    end
  end

  # Selects a sub-category for a filter type that offers sub-categories
  # @param filter_key [String]
  # @param filter_option [String]
  def choose_new_filter_sub_option(filter_key, filter_option)
    # GPA and Last Name require input
    if %w(gpaRanges lastNameRanges).include? filter_key
      wait_for_element_and_type(filter_range_min_input_element, filter_option['min'])
      wait_for_element_and_type(filter_range_max_input_element, filter_option['max'])

    # All others require a selection
    else
      wait_for_update_and_click new_sub_filter_button_element
      wait_for_update_and_click new_filter_sub_option_element(filter_key, filter_option)
    end
  end

  # Selects, adds, and applies a filter
  # @param filter_key [String]
  # @param filter_option [String]
  def select_new_filter(filter_key, filter_option = nil)
    logger.info "Selecting #{filter_key} #{filter_option}"
    click_new_filter_button
    wait_for_update_and_click new_filter_option(filter_key)

    # Some have no sub-options
    no_options = %w(midpointDeficient transfer underrepresented isInactiveAsc inIntensiveCohort isInactiveCoe coeUnderrepresented coeProbation)
    choose_new_filter_sub_option(filter_key, filter_option) unless no_options.include? filter_key
    wait_for_update_and_click unsaved_filter_add_button_element
    unsaved_filter_apply_button_element.when_present Utils.short_wait
  end

  # Executes a custom cohort search using search criteria associated with a cohort and stores the result count
  # @param cohort [FilteredCohort]
  def perform_search(cohort)

    # The squads and majors lists can change over time. Avoid test failures if the search criteria is out of sync
    # with actual squads or majors. Advisors might also change, but fail if this happens for now.
    if cohort.search_criteria.major&.any?
      click_new_filter_button
      wait_for_update_and_click new_filter_option('majors')
      wait_for_update_and_click new_filter_sub_option_button
      sleep Utils.click_wait
      filters_missing = []
      cohort.search_criteria.major.each { |major| filters_missing << major unless new_filter_sub_option_element('majors', major).exists? }
      logger.debug "The majors #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
      filters_missing.each { |f| cohort.search_criteria.major.delete f }
      wait_for_update_and_click unsaved_filter_cancel_button_element
    end
    if cohort.search_criteria.asc_team&.any?
      wait_for_update_and_click new_filter_button_element
      wait_for_update_and_click new_filter_option('groupCodes')
      wait_for_update_and_click new_sub_filter_button_element
      sleep 2
      filters_missing = []
      cohort.search_criteria.asc_team.each { |squad| filters_missing << squad unless new_filter_sub_option_element('groupCodes', squad.name).exists? }
      logger.debug "The squads #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
      filters_missing.each { |f| cohort.search_criteria.asc_team.delete f }
      wait_for_update_and_click unsaved_filter_cancel_button_element
    end

    # Global
    cohort.search_criteria.entering_terms.each { |term| select_new_filter('enteringTerms', term) } if cohort.search_criteria.entering_terms
    cohort.search_criteria.gpa.each { |gpa| select_new_filter('gpaRanges', gpa) } if cohort.search_criteria.gpa
    cohort.search_criteria.level.each { |l| select_new_filter('levels', l) } if cohort.search_criteria.level
    cohort.search_criteria.units_completed.each { |u| select_new_filter('unitRanges', u) } if cohort.search_criteria.units_completed
    cohort.search_criteria.major.each { |m| select_new_filter('majors', m) } if cohort.search_criteria.major
    select_new_filter 'midpointDeficient' if cohort.search_criteria.mid_point_deficient
    select_new_filter 'transfer' if cohort.search_criteria.transfer_student
    cohort.search_criteria.expected_grad_terms.each { |t| select_new_filter('expectedGradTerms', t) } if cohort.search_criteria.expected_grad_terms
    cohort.search_criteria.last_name.each { |n| select_new_filter('lastNameRanges', n) } if cohort.search_criteria.last_name
    cohort.search_criteria.gender.each { |g| select_new_filter('genders', g) } if cohort.search_criteria.gender
    cohort.search_criteria.cohort_owner_academic_plans.each { |e| select_new_filter('cohortOwnerAcademicPlans', e) } if cohort.search_criteria.cohort_owner_academic_plans
    select_new_filter 'underrepresented' if cohort.search_criteria.underrepresented_minority
    cohort.search_criteria.ethnicity.each { |e| select_new_filter('ethnicities', e) } if cohort.search_criteria.ethnicity

    # CoE
    cohort.search_criteria.coe_advisor.each { |a| select_new_filter('coeAdvisorLdapUids', a) } if cohort.search_criteria.coe_advisor
    cohort.search_criteria.coe_ethnicity.each { |e| select_new_filter('coeEthnicities', e) } if cohort.search_criteria.coe_ethnicity
    select_new_filter 'coeUnderrepresented' if cohort.search_criteria.coe_underrepresented_minority
    cohort.search_criteria.coe_gender.each { |g| select_new_filter('coeGenders', g) } if cohort.search_criteria.coe_gender
    cohort.search_criteria.coe_prep.each { |p| select_new_filter('coePrepStatuses', p) } if cohort.search_criteria.coe_prep
    select_new_filter 'coeProbation' if cohort.search_criteria.coe_probation
    select_new_filter 'isInactiveCoe' if cohort.search_criteria.coe_inactive

    # ASC
    select_new_filter 'isInactiveAsc' if cohort.search_criteria.asc_inactive
    select_new_filter 'inIntensiveCohort' if cohort.search_criteria.asc_intensive
    cohort.search_criteria.asc_team.each { |s| select_new_filter('groupCodes', s.name) } if cohort.search_criteria.asc_team

    # If there are any search criteria left, execute search and log time search took to complete
    if cohort.search_criteria.list_filters.flatten.compact.any?
      wait_for_update_and_click unsaved_filter_apply_button_element
      cohort.member_count = wait_for_search_results
      logger.warn "No results found for #{cohort.search_criteria.list_filters}" if cohort.member_count.zero?

    # If no search criteria remain, do not try to search
    else
      logger.warn 'None of the search criteria are available in the UI'
      cohort.member_count = 0
    end
  end

  # EXISTING FILTERED COHORTS - Viewing

  button(:show_filters_button, xpath: "//button[contains(.,'Show Filters')]")
  elements(:cohort_filter_row, :div, class: 'filter-row')

  # Ensures that cohort filters are visible
  def show_filters
    button_element(id: 'show-hide-details-button').when_visible Utils.medium_wait
    show_filters_button if show_filters_button?
  end

  # Returns the XPath to the filter name on a filter row
  # @param filter_name [String]
  # @return [String]
  def existing_filter_xpath(filter_name)
    (['Ethnicity', 'Gender', 'Underrepresented Minority'].include? filter_name) ?
        "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\") and not(contains(.,\"COE\"))]" :
        "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\")]"
  end

  # Returns the element containing an added cohort filter
  # @param filter_option [String]
  # @return [PageObject::Elements::Element]
  def existing_filter_element(filter_name, filter_option = nil)
    filter_option_xpath = "#{existing_filter_xpath filter_name}/following-sibling::div"

    if ['Inactive', 'Inactive (ASC)', 'Inactive (COE)', 'Intensive', 'Probation', 'Transfer Student',
        'Underrepresented Minority', 'Underrepresented Minority (COE)'].include? filter_name
      div_element(xpath: existing_filter_xpath(filter_name))

    elsif filter_name == 'Last Name'
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option['min'] + ' through ' + filter_option['max']}\")]")

    elsif filter_name == 'GPA'
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{sprintf('%.3f', filter_option['min']) + ' - ' + sprintf('%.3f', filter_option['max'])}\")]")

    elsif %w(Ethnicity Gender).include? filter_name
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option}\") and not(contains(.,\"COE\"))]")

    else
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option}\")]")
    end
  end

  # Verifies that a cohort's filters are visibly selected
  # @param cohort [FilteredCohort]
  def verify_filters_present(cohort)
    if cohort.search_criteria.list_filters.flatten.compact.any?
      show_filters
      wait_until(Utils.short_wait) { cohort_filter_row_elements.any? }
      filters = cohort.search_criteria
      wait_until(5) do

        filters.entering_terms.each { |term| existing_filter_element('Entering Term', term).exists? } if filters.entering_terms&.any?
        filters.expected_grad_terms.each { |t| existing_filter_element('Expected Graduation Term', t).exists? } if filters.expected_grad_terms&.any?
        filters.gpa.each { |g| existing_filter_element('GPA', g).exists? } if filters.gpa&.any?
        filters.level.each { |l| existing_filter_element('Level', l).exists? } if filters.level&.any?
        filters.major.each { |m| existing_filter_element('Major', m).exists? } if filters.major&.any?
        existing_filter_element('Midpoint Deficient Grade').exists? if filters.mid_point_deficient
        existing_filter_element('Transfer Student').exists? if filters.transfer_student
        filters.units_completed.each { |u| existing_filter_element('Units Completed', u).exists? } if filters.units_completed&.any?

        filters.ethnicity.each { |e| existing_filter_element('Ethnicity', e).exists? } if filters.ethnicity&.any?
        filters.gender.each { |g| existing_filter_element('Gender', g).exists? } if filters.gender&.any?
        existing_filter_element('Underrepresented Minority').exists? if filters.underrepresented_minority

        existing_filter_element('Inactive (ASC)').exists? if filters.asc_inactive
        existing_filter_element('Intensive').exists? if filters.asc_intensive
        filters.asc_team.each { |t| existing_filter_element('Team', t.name).exists? } if filters.asc_team&.any?

        # TODO - advisors COE
        filters.coe_ethnicity.each { |e| existing_filter_element('Ethnicity (COE)', e).exists? } if filters.coe_ethnicity&.any?
        filters.coe_gender.each { |g| existing_filter_element('Gender (COE)', g).exists? } if filters.coe_gender&.any?
        existing_filter_element('Inactive (COE)').exists? if filters.coe_inactive

        filters.last_name.each { |n| existing_filter_element('Last Name', n).exists? } if filters.last_name&.any?
        filters.cohort_owner_academic_plans.each { |g| existing_filter_element('My Students', g).exists? } if filters.cohort_owner_academic_plans&.any?

        existing_filter_element('Underrepresented Minority').exists? if filters.coe_underrepresented_minority
        filters.coe_prep.each { |p| existing_filter_element('PREP', p).exists? } if filters.coe_prep&.any?
        existing_filter_element('Probation').exists? if filters.coe_probation
        true
      end
    else
      unsaved_filter_apply_button_element.when_not_visible Utils.short_wait
      wait_until(1) { cohort_filter_row_elements.empty? }
    end
  end

  # EXISTING FILTERED COHORTS - Editing

  elements(:cohort_edit_button, :button, xpath: '//button[contains(@id, "edit-added-filter")]')

  # Returns the XPath to the Edit, Cancel, and Update controls for a filter row
  # @param filter_name [String]
  # @return [String]
  def filter_controls_xpath(filter_name)
    "#{existing_filter_xpath filter_name}/following-sibling::div[2]"
  end

  # Returns the XPath for an existing filter sub-option
  # @param [String] filter_name
  # @return [String]
  def existing_filter_sub_options_xpath(filter_name)
    "#{existing_filter_xpath filter_name}/following-sibling::div"
  end

  # Clicks a sub-option when editing an existing filter
  # @param [String] filter_name
  # @param [String] edited_filter_option
  def choose_edit_filter_sub_option(filter_name, edited_filter_option)
    # Last Name requires input
    if ['GPA', 'Last Name'].include? filter_name
      wait_for_element_and_type(text_area_element(xpath: "//input[contains(@id, 'filter-range-min-')]"), edited_filter_option['min'])
      wait_for_element_and_type(text_area_element(xpath: "//input[contains(@id, 'filter-range-max-')]"), edited_filter_option['max'])

    # All others require a selection
    else
      wait_for_update_and_click button_element(xpath: "#{existing_filter_sub_options_xpath filter_name}//button")
      (['Entering Term', 'Expected Graduation Term', 'Advisor (COE)'].include? filter_name) ?
          wait_for_update_and_click(link_element(id: "#{filter_name}-#{edited_filter_option}")) :
          wait_for_update_and_click(link_element(xpath: "#{existing_filter_sub_options_xpath filter_name}//span[text()=\"#{edited_filter_option}\"]/.."))
    end
  end

  # Edits the first filter of a given type
  # @param filter_key [String]
  # @param new_filter_option [String]
  def edit_filter_of_type(filter_key, new_filter_option)
    wait_for_update_and_click button_element(xpath: "#{filter_controls_xpath filter_key}//button[contains(.,'Edit')]")
    choose_edit_filter_sub_option(filter_key, new_filter_option)
  end

  # Clicks the cancel button for the first filter of a given type that is in edit mode
  # @param filter_name [String]
  def cancel_filter_edit(filter_name)
    el = button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Cancel')]")
    wait_for_update_and_click el
    el.when_not_present 1
  end

  # Clicks the update button for the first filter of a given type that is in edit mode
  # @param filter_name [String]
  def confirm_filter_edit(filter_name)
    el = button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Update')]")
    wait_for_update_and_click el
    el.when_not_present 1
  end

  # Saves an edit to the first filter of a given type
  # @param filter_name [String]
  # @param filter_option [String]
  def edit_filter_and_confirm(filter_name, filter_option)
    logger.info "Changing '#{filter_name}' to '#{filter_option}'"
    edit_filter_of_type(filter_name, filter_option)
    confirm_filter_edit(filter_name)
  end

  # Removes the first filter of a given type
  # @param filter_name [String]
  def remove_filter_of_type(filter_name)
    logger.info "Removing '#{filter_name}'"
    row_count = cohort_filter_row_elements.length
    wait_for_update_and_click button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Remove')]")
    wait_until(Utils.short_wait) { cohort_filter_row_elements.length == row_count - 1 }
  end

end
