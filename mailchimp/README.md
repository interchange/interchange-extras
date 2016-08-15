# MailChimp & Mandrill

This integrates Interchange with MailChimp API version 3, and Mandrill
API version 1.

## Requirements

- Perl 5.20 or higher
- [Mail::Chimp3](http://p3rl.org/Mail::Chimp3) CPAN module

## Installation

* run `cpanm --installdeps .` (or just `cpanm Mail::Chimp3`)

* copy over files:

    - _The `i` directory represents the path to your Interchange Server
      (perhaps `/usr/local/interchange`)._

    - i/usertag/mailchimp.tag

        * call this tag from an mv_click for a newsletter signup form, e.g.:

            ```
            [set doSubscribe]
                [mailchimp ...]
            [/set]
            <form ...>
            ...
            <input type=hidden name=mv_form_profile ...>
            <input type=hidden name=mv_click value=doSubscribe>
            ```

    - i/usertag/mailchimp360.tag

        * IC support for Ecommerce360, allows reporting orders back to
          MailChimp
          http://kb.mailchimp.com/integrations/e-commerce/how-to-use-mailchimp-for-e-commerce


    - i/usertag/mailchimp_queue.tag

    - i/usertag/mandrill*

    - i/usertag/logger.tag

    - i/lib/Ext/MailChimp3.pm

    - dbconf/[mysql-or-pgsql]/mailchimp_queue.*

    - etc/jobs/minutes5/mailchimp_queue

    - products/mailchimp_queue.txt


* add cronjob to run the minutes5 job, e.g.:

    ```
    */5 * * * * interchange/bin/interchange --runjobs=YOUR_CATALOG=minutes5 --quiet > /dev/null 2>/dev/null
    ```

* Restart Interchange.



See POD in various tags and modules for documentation (e.g. `perldoc
i/usertag/mailchimp.tag`).
