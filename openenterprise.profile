<?php

/**
* A trick to enforce page refresh when theme is changed from an overlay.
*/
function openenterprise_admin_paths_alter(&$paths) {
  $paths['admin/appearance/default*'] = FALSE;
}

/**
 * Implements hook_appstore_stores_info
 */
function openenterprise_apps_servers_info() {
  $profile = variable_get('install_profile', 'standard');
  $info =  drupal_parse_info_file(drupal_get_path('profile', $profile) . '/' . $profile . '.info');
  return array(
    'levelten' => array(
      'title' => 'LevelTen',
      'description' => "Apps from LevelTen Interactive",
      'manifest' => 'http://apps.leveltendesign.com/app/query',
      'profile' => $profile,
      'profile_version' => isset($info['version']) ? $info['version'] : '7.x-1.x',
      'server_name' => $_SERVER['SERVER_NAME'],
      'server_ip' => $_SERVER['SERVER_ADDR'],
    ),
  );
}

/**
 * implements hook_install_configure_form_alter()
 */
function openenterprise_form_install_configure_form_alter(&$form, &$form_state) {
  // Many modules set messages during installation that are very annoying.
  // (I'm looking at you Date and IMCE)
  // Lets remove these and readd the only message that should be set.
  drupal_get_messages('status');
  drupal_get_messages('warning');

  // Warn about settings.php permissions risk
  $settings_dir = conf_path();
  $settings_file = $settings_dir . '/settings.php';
  // Check that $_POST is empty so we only show this message when the form is
  // first displayed, not on the next page after it is submitted. (We do not
  // want to repeat it multiple times because it is a general warning that is
  // not related to the rest of the installation process; it would also be
  // especially out of place on the last page of the installer, where it would
  // distract from the message that the Drupal installation has completed
  // successfully.)
  if (empty($_POST) && (!drupal_verify_install_file(DRUPAL_ROOT . '/' . $settings_file, FILE_EXIST|FILE_READABLE|FILE_NOT_WRITABLE) || !drupal_verify_install_file(DRUPAL_ROOT . '/' . $settings_dir, FILE_NOT_WRITABLE, 'dir'))) {
    drupal_set_message(st('All necessary changes to %dir and %file have been made, so you should remove write permissions to them now in order to avoid security risks. If you are unsure how to do so, consult the <a href="@handbook_url">online handbook</a>.', array('%dir' => $settings_dir, '%file' => $settings_file, '@handbook_url' => 'http://drupal.org/server-permissions')), 'warning');
  }

  $form['site_information']['site_name']['#default_value'] = 'OpenEnterprise';
  $form['site_information']['site_mail']['#default_value'] = 'admin@'. $_SERVER['HTTP_HOST'];
  $form['admin_account']['account']['name']['#default_value'] = 'admin';
  $form['admin_account']['account']['mail']['#default_value'] = 'admin@'. $_SERVER['HTTP_HOST'];
}

/**
 * Set Open Enterprise as default install profile.
 *
 * Must use system as the hook module because openenterprise is not active yet
 */
function system_form_install_select_profile_form_alter(&$form, $form_state) {
  // Hide default drupal profiles
  unset($form['profile']['Minimal']);
  unset($form['profile']['Standard']);
  foreach($form['profile'] as $key => $element) {
    $form['profile'][$key]['#value'] = 'openenterprise';
  }
}

/**
 * Implements hook_install_tasks
 */
function openenterprise_install_tasks($install_state) {
  // Only use apps forms during interactive installs.
  if ($install_state['interactive']) {
    require_once drupal_get_path('profile', 'openenterprise') . '/openenterprise.appinstaller.inc';
    $tasks = array(
      'openenterprise_apps_select_form' => array(
        'display_name' => st('Install Apps'),
        'type' => 'form',
      ),
      'openenterprise_download_app_modules' => array(
        'display' => FALSE,
        'type' => 'batch',
        'run' => (isset($_SESSION['apps']))?INSTALL_TASK_RUN_IF_NOT_COMPLETED:INSTALL_TASK_SKIP,
      ),
      // Only need this if using filetransfer authorization.
      'openenterprise_authorize_transfer' => array(
        'display' => FALSE,
        'type' => 'form',
        'run' => (!is_writeable(conf_path()) && isset($_SESSION['apps']))?INSTALL_TASK_RUN_IF_NOT_COMPLETED:INSTALL_TASK_SKIP,
      ),
      'openenterprise_install_app_modules' => array(
        'display' => FALSE,
        'type' => 'batch',
        'run' => (isset($_SESSION['apps']))?INSTALL_TASK_RUN_IF_NOT_COMPLETED:INSTALL_TASK_SKIP,
      ),
      'openenterprise_enable_app_modules' => array(
        'display' => FALSE,
        'run' => (isset($_SESSION['apps']))?INSTALL_TASK_RUN_IF_NOT_COMPLETED:INSTALL_TASK_SKIP,
      ),
    );
  }
  return $tasks;
}

/**
 * Change the final task to our task
 */
function openenterprise_install_tasks_alter(&$tasks, $install_state) {
  $tasks['install_finished']['function'] = "openenterprise_install_finished";
}

/**
 * Installation task; perform final steps and display a 'finished' page.
 *
 * @param $install_state
 *   An array of information about the current installation state.
 *
 * @return
 *   A message informing the user that the installation is complete.
 */
function openenterprise_install_finished(&$install_state) {
  drupal_set_title(st('@drupal installation complete', array('@drupal' => drupal_install_profile_distribution_name())), PASS_THROUGH);
  if (empty($_SESSION['apps'])) {
    $output = '<h2>' . st('Congratulations, you installed @drupal!', array('@drupal' => drupal_install_profile_distribution_name())) . '</h2>';
    $output .= '<p>' . st('By not installing any apps, your site is currently a blank. To get started you can either create your own content types, views and set up the site yourself or install some prebuild apps. Apps provide complete bundled functionality that will greatly speed up the process of creating your site.') . '</p>';
    $output .= '<p>' . st('Even after installing apps your site may look very empty before you add some content. To see what it looks like with content, try installing the default content for each of the apps. This can be done on each app\'s configuration page.') . '</p>';
    $output .= '<h2>' . st('Next Step') . '</h2>';
    $output .= '<p>' . st('<a href="@url">Install some apps</a>', array('@url' => url('admin/apps'))) . ' or ' . st('<a href="@url">go to your site\'s home page</a>.', array('@url' => url('<front>'))) . '</p>';
  }
  else {
    $link = (isset($_SESSION['apps_default_content']))?drupal_get_normal_path('home'):'<front>';
    $output = '<h2>' . st('Congratulations, you installed @drupal!', array('@drupal' => drupal_install_profile_distribution_name())) . '</h2>';
    $output .= '<p>' . st('Your site now contains the apps you selected. To add more, go to the Apps menu in the admin menu at the top of the site.') . '</p>';
    $output .= '<h2>' . st('Next Step') . '</h2>';
    $output .= '<p>' . st('<a href="@url">Go to your site\'s home page</a>.', array('@url' => url($link))) . '</p>';
  }

  // Flush all caches to ensure that any full bootstraps during the installer
  // do not leave stale cached data, and that any content types or other items
  // registered by the install profile are registered correctly.
  drupal_flush_all_caches();

  // Remember the profile which was used.
  variable_set('install_profile', drupal_get_profile());

  // Install profiles are always loaded last
  db_update('system')
    ->fields(array('weight' => 1000))
    ->condition('type', 'module')
    ->condition('name', drupal_get_profile())
    ->execute();

  // Cache a fully-built schema.
  drupal_get_schema(NULL, TRUE);

  // Run cron to populate update status tables (if available) so that users
  // will be warned if they've installed an out of date Drupal version.
  // Will also trigger indexing of profile-supplied content or feeds.
  drupal_cron_run();

  return $output;
}
/**
 * Implements hook_block_info()
 */
function openenterprise_block_info() {
  $blocks['powered-by'] = array(
    'info' => t('Powered by OpenEnterprise'),
    'weight' => '10',
    'cache' => DRUPAL_NO_CACHE,
  );
  return $blocks;
}

/**
 * Implements hook_block_view().
 */
function openenterprise_block_view($delta = '') {
  $block = array();
  switch ($delta) {
    case 'powered-by':
      $block['subject'] = NULL;
      $block['content'] = '<span>' . t('Powered by <a href="http://apps.leveltendesign.com/project/openenterprise" target="_blank">OpenEnterprise</a>. A distribution by <a href="http://www.leveltendesign.com" target="_blank">LevelTen Interactive</a>') . '</span>';
      return $block;
  }
}
