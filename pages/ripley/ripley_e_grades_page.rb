require_relative '../../util/spec_helper'

class RipleyEGradesPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:back_to_gradebook_link, text: 'Back to Gradebook')
  link(:how_to_post_grades_link, id: 'link-to-httpscommunitycanvaslmscomdocsDOC1733041521116619')
  link(:course_settings_button, id: 'canvas-course-settings-href')

  radio_button(:pnp_cutoff_radio, id: 'input-enable-pnp-conversion-true')
  radio_button(:no_pnp_cutoff_radio, id: 'input-enable-pnp-conversion-false')
  select_list(:cutoff_select, id: 'select-pnp-grade-cutoff')
  select_list(:sections_select, id: 'course-sections')
  button(:download_current_grades, id: 'download-current-grades-button')
  button(:download_final_grades, id: 'download-final-grades-button')
  link(:bcourses_to_egrades_link, id: 'link-to-httpsberkeleyservicenowcomkbidkb_article_viewsysparm_articleKB0010659sys_kb_id8b7818e11b1837ccbc27feeccd4bcbbe')

  div(:non_teacher_msg, xpath: '//div[text()="You must be a teacher in this bCourses course to export to E-Grades CSV."]')

  def embedded_tool_path(course_site)
    "/courses/#{course_site.site_id}/external_tools/#{RipleyTool::E_GRADES.tool_id}"
  end

  def hit_embedded_tool_url(course_site)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course_site}"
  end

  def load_embedded_tool(course_site)
    load_tool_in_canvas embedded_tool_path(course_site)
  end

  def load_standalone_tool(course_site)
    navigate_to "#{RipleyUtils.base_url} TBD #{course_site.site_id}"
  end

  def click_course_settings_button(course_site)
    wait_for_load_and_click course_settings_button_element
    wait_until(Utils.medium_wait) { current_url.include? "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/settings" }
  end

  def set_cutoff(cutoff)
    if cutoff
      logger.info "Setting P/NP cutoff to '#{cutoff}'"
      wait_for_element_and_select(cutoff_select_element, cutoff)
    else
      logger.info 'Setting no P/NP cutoff'
      wait_for_update_and_click no_pnp_cutoff_radio_element
    end
  end

  def choose_section(section)
    section_name = "#{section.course} #{section.label}"
    Utils.prepare_download_dir
    wait_for_element_and_select(sections_select_element, section_name)
  end

  def download_current_grades(course_site, section, cutoff = nil)
    logger.info "Downloading current grades for #{course_site.course.code} #{section.label}"
    file_name = "egrades-current-#{section.id}-#{course_site.course.term.name.gsub(' ', '-')}-*.csv"
    download_grades(course_site, section, file_name, {cutoff: cutoff, final: false})
  end

  def download_final_grades(course_site, section, cutoff = nil)
    logger.info "Downloading final grades for #{course_site.course.code} #{section.label}"
    file_name = "egrades-final-#{section.id}-#{course_site.course.term.name.gsub(' ', '-')}-*.csv"
    download_grades(course_site, section, file_name, {cutoff: cutoff, final: true})
  end

  def download_grades(course_site, section, file_name, opts={})
    load_embedded_tool course_site
    click_continue
    set_cutoff opts[:cutoff]
    choose_section section if course_site.course.sections.length > 1
    sleep 1
    el = opts[:final] ? download_final_grades_element : download_current_grades_element
    parse_downloaded_csv(el, file_name)
  end
end
