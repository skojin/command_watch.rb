# Command Watch

Check command output and send notification if something changed

Setup cron task: */5 * * * * cd /install/path && ./command_watch.rb

```
config.yml

name:
  enabled: true  # true|false, default true
  # we check output of this :watch command
  watch: curl -s http://example.com | pup -p title text{}
  # if output is different from previous call, then :do command will be called
  # :do gets output of :watch as STDIN
  # this email will have new title in body
  do: mail -s "Title has changed" mail@example.com
date:
  enabled: false
  watch: date "+%Y-%m-%d"
  do: mail -s "new day" mail@example.com
diff:
  watch: date
  # $1 if current result of watch command
  # $2 is previous result
  do: echo $1 $2 > diff.txt



```
