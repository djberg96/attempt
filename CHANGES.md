## 0.6.3 - 26-Jun-2024
* Rubocop cleanup.

## 0.6.2 - 2-Jun-2022
* The safe_timeout library is not used on MS Windows.

## 0.6.1 - 20-Oct-2020
* Switched the README, MANIFEST and CHANGES to markdown format.
* Fiddling with the .travis.yml file again.

## 0.6.0 - 17-Sep-2020

* Switched from test-unit to rspec and rewrote the specs.

## 0.5.1 - 28-Aug-2020

* Added a Gemfile.
* Updated Rakefile to clean .lock files.
* Bumped structured_warnings version to 0.4.0 so that it works with Ruby 2.7.
  Thanks go to Alexey Zapriy for the spot.

## 0.5.0 - 2-Jun-2020

* Switched to Apache-2.0 license, added LICENSE file.
* Updated cert again.

## 0.4.0 - 5-Sep-2017

* Switched constructor to use keyword arguments.
* Replaced Timeout with SafeTimeout and added the safe_timeout dependency.
* The :log option now accepts either an IO or Logger object.
* Updated cert.

## 0.3.2 - 4-Apr-2017

* Fix metadata key names.

## 0.3.1 - 4-Apr-2017

* Added some metadata to the gemspec.

## 0.3.0 - 27-Mar-2017

* The structured_warnings gem requirement was updated to 0.3.0 or later. This
  is necessary if you are using Ruby 2.4 or later.
* The VERSION string is now frozen.
* Updated the certs file.

## 0.2.1 - 13-Dec-2015

* This gem is now signed.
* Updates to the Rakefile and gemspec.
* Added a caveat regarding the timeout module to the README.

## 0.2.0 - 26-Sep-2009

* Now requires and uses the structured_warnings gem. If a block of code fails
  prior to reaching the maximum number of tries, and warnings are on, then
  an Attempt::Warning is raised.
* Fixed a packaging bug.
* Refactored the attempt.gemspec file a bit.
* Added the 'gem' task to the Rakefile.

## 0.1.2 - 1-Aug-2009

* License changed to Artistic 2.0.
* Added test-unit as a development dependency.
* Test file renamed to more closely follow Ruby style.
* Gemspec updates, including addition of license.

## 0.1.1 - 31-Jul-2007

* Added a Rakefile with tasks for testing and installation.
* Removed the install.rb file, since installation is now handled by the Rakefile.
* Some minor doc updates.

## 0.1.0 - 9-Jun-2006

* Initial commit
