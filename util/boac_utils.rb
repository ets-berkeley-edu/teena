require_relative 'spec_helper'

class BOACUtils < Utils

  @config = Utils.config['boac']

  # Returns the BOAC test environment URL
  # @return [String]
  def self.base_url
    @config['base_url']
  end

  # Returns the BOAC dev auth password
  # @return [String]
  def self.password
    @config['password']
  end

  # Returns the current BOAC semester
  # @return [String]
  def self.term
    @config['term']
  end

  # Returns the current BOAC semester code
  def self.term_code
    @config['term_code']
  end

  # Returns the term to be used for testing assignments
  def self.assignments_term
    @config['assignments_term']
  end

  # Whether or not to check tooltips during tests. Checking tooltips slows down test execution.
  def self.tooltips
    @config['tooltips']
  end

  # Whether or not to check Nessie assignment scores during tests.
  def self.nessie_scores
    @config['nessie_scores']
  end

  # Whether or not to check Nessie assignments submission counts during tests.
  def self.nessie_assignments
    @config['nessie_assignments']
  end

  # Whether or not to compare student data to fellow cohort members in Canvas prod
  def self.last_activity_context
    @config['last_activity_context']
  end

  # Logs error, prints stack trace, and saves a screenshot when running headlessly
  def self.log_error_and_screenshot(driver, error, unique_id)
    log_error error
    save_screenshot(driver, unique_id) if Utils.headless?
  end

  # SEARCH TEST DATA

  # Returns the file path containing stored searchable student data to drive cohort search tests
  # @return [String]
  def self.searchable_data
    File.join(Utils.config_dir, "boac-searchable-data-#{Time.now.strftime('%Y-%m-%d')}.json")
  end

  # Returns the db credentials for BOAC
  # @return [Hash]
  def self.boac_db_credentials
    {
      host: @config['db_host'],
      port: @config['db_port'],
      name: @config['db_name'],
      user: @config['db_user'],
      password: @config['db_password']
    }
  end

  # DATABASE - USERS

  # Returns all admin users
  # @return [Array<BOACUser>]
  def self.get_admin_users
    query = 'SELECT authorized_users.uid AS uid
              FROM authorized_users
              WHERE authorized_users.is_admin = true;'
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| BOACUser.new({uid: r['uid']}) }
  end

  # Returns all the advisors associated with a department
  # @return [Array<BOACUser>]
  def self.get_dept_advisors(dept)
    query = "SELECT authorized_users.uid
              FROM authorized_users
              INNER JOIN university_dept_members ON authorized_users.id = university_dept_members.authorized_user_id
              INNER JOIN university_depts on university_dept_members.university_dept_id = university_depts.id
              WHERE university_depts.dept_code = '#{dept.code}';"
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| BOACUser.new({uid: r['uid']}) }
  end

  # DATABASE - CURATED GROUPS

  # Returns the curated groups belonging to a given user
  # @param user [BOACUser]
  # @return [Array<CuratedGroup>]
  def self.get_user_curated_groups(user)
    query = "SELECT student_groups.id AS id, student_groups.name AS name
              FROM student_groups
              JOIN authorized_users ON authorized_users.id = student_groups.owner_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| CuratedGroup.new({id: r['id'], name: r['name'], owner_uid: user.uid}) }
  end

  # Obtains and sets the ID given a curated group with a unique title
  # @param group [CuratedGroup]
  def self.set_curated_group_id(group)
    query = "SELECT id
              FROM student_groups
              WHERE name = '#{group.name}';"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Curated group '#{group.name}' ID is #{result}"
    group.id = result
  end

  # DATABASE - FILTERED COHORTS

  # Returns the filtered cohorts belonging to a given user
  # @param user [BOACUser]
  # @return [Array<FilteredCohort>]
  def self.get_user_filtered_cohorts(user)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map do |r|
      FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid})
    end
  end

  # Returns all filtered cohorts. If a department is given, then returns only the cohorts associated with that department.
  # @param dept [BOACDepartments]
  # @return [Array<FilteredCohort>]
  def self.get_everyone_filtered_cohorts(dept = nil)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria,
                    authorized_users.uid AS uid
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              #{if dept
                 'JOIN university_dept_members ON university_dept_members.authorized_user_id = authorized_users.id
                  JOIN university_depts ON university_depts.id = university_dept_members.university_dept_id
                  WHERE university_depts.dept_code = \'' + dept.code + '\' '
                end}
              ORDER BY uid, cohort_id ASC;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    cohorts = results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: r['uid']}) }
    cohorts.sort_by { |c| [c.owner_uid.to_i, c.id] }
  end

  # Obtains and sets the cohort ID given a filtered cohort with a unique title
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def self.set_filtered_cohort_id(cohort)
    query = "SELECT id
             FROM cohort_filters
             WHERE name = '#{cohort.name}';"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Filtered cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

  # DATABASE - ALERTS

  # Given a set of students, returns all their active alerts in the current term
  # @param users [Array<BOACUser>]
  # @return [Array<Alert>]
  def self.get_students_alerts(users)
    sids = users.map(&:sis_id).to_s.delete('[]')
    query = "SELECT id, sid, alert_type, message
              FROM alerts
              WHERE sid IN (#{sids})
                AND active = true
                AND key LIKE '#{term_code}%';"
    results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
    alerts = results.map { |r| Alert.new({id: r['id'], type: r['alert_type'], message: r['message'].gsub("\n", ' ').gsub(/\s+/, ' '), user: BOACUser.new({sis_id: r['sid']})}) }
    alerts.sort_by &:message
  end

  # Given a set of students, returns all their active alerts in the current term that have not been dismissed by an advisor. If no
  # advisor is specified, then the test admin user is the advisor by default.
  def self.get_un_dismissed_users_alerts(students, advisor = nil)
    alerts = get_students_alerts students
    dismissed_alerts = get_dismissed_alerts(alerts, advisor)
    alerts - dismissed_alerts
  end

  # Given a set of alerts, returns those that have been dismissed by an advisor. If no advisor is specificed, then the test admin user
  # is the advisor by default.
  # @param alerts [Array<Alert>]
  # @param advisor [BOACUser]
  # @return [Array<Alert>]
  def self.get_dismissed_alerts(alerts, advisor = nil)
    if alerts.any?
      alert_ids = (alerts.map &:id).join(', ')
      query = "SELECT alert_views.alert_id
                FROM alert_views
                JOIN authorized_users ON authorized_users.id = alert_views.viewer_id
                WHERE alert_views.alert_id IN (#{alert_ids})
                  AND authorized_users.uid = '#{advisor ? advisor.uid : Utils.super_admin_uid}';"
      results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
      dismissed = results.map { |r| r['alert_id'].to_s }
      alerts.select { |a| dismissed.include? a.id }
    else
      alerts
    end
  end

  # Deletes the dismissal of an alert by a given advisor or the admin test user by default
  # @param alert [Alert]
  # @param advisor [BOACUser]
  def self.remove_alert_dismissal(alert, advisor = nil)
    query = "DELETE
              FROM alert_views
              WHERE alert_views.alert_id = '#{alert.id}'
                AND alert_views.viewer_id IN (SELECT authorized_users.id
                                              FROM authorized_users
                                              WHERE authorized_users.uid = '#{advisor ? advisor.uid : Utils.super_admin_uid}');"
    Utils.query_pg_db(boac_db_credentials, query)
  end

  # Returns an alert that has not been dismissed by the admin test user
  # @return [Alert]
  def self.get_test_alert
    # Get one active alert in the current term
    query = "SELECT alerts.id, alerts.sid, alerts.alert_type, alerts.message
              FROM alerts
              WHERE active = true
                AND key LIKE '#{term_code}%'
              LIMIT 1;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    alert = (results.map { |r| Alert.new({id: r['id'], message: r['message'], user: BOACUser.new({sis_id: r['sid']})}) }).first
    # If an alert exists and the admin tester has dismissed the alert, delete the dismissal to permit dismissal testing
    if alert
      remove_alert_dismissal(alert) if get_dismissed_alerts([alert]).any?
      logger.info "Test alert ID #{alert.id}, message '#{alert.message}', user SID #{alert.user.sis_id}"
    end
    alert
  end

end
