# Command Watch

Check command output and send notification if something changed

Setup cron task: */5 * * * * cd /install/path && ./command_watch.rb

```yaml
config.yml

name:
  enabled: true  # true|false, default true
  skip_error: false  # true|false, default false, skip :do command if :watch command return non zero code, useful if curl sometimes return bad code
  # we check output of this :watch command
  watch: curl -s http://example.com | pup -p title text{}
  # if output is different from previous call, then :do command will be called
  # :do gets output of :watch as STDIN
  # this email will have new title in body
  do: mail -s "Title has changed" mail@example.com
date:
  enabled: false
  watch: date "+%Y-%m-%d"
  do: curl -i -X GET "https://api.telegram.org/BOTID:TOKEN/sendMessage" -F "chat_id=CHAT_ID" -F "text=new day $1"
diff:
  watch: date
  # $1 if current result of watch command
  # $2 is previous result
  do: echo "$1 $2" > diff.txt

```

## See Also
https://github.com/skojin/webwatch
