# fluent-plugin-quota-throttle

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/rubrikinc/fluent-plugin-throttle/blob/master/LICENSE) ![Rake Test](https://github.com/rubrikinc/fluent-plugin-quota-throttle/actions/workflows/ruby.yml/badge.svg) [![Gem Version](https://badge.fury.io/rb/fluent-plugin-quota-throttle.svg)](https://badge.fury.io/rb/fluent-plugin-quota-throttle)

A sentry plugin to throttle logs based on well defined quotas. Logs are grouped by configurable keys. When
a group exceeds a configuration rate, logs are dropped for this group.

## Installation

install with `gem` or td-agent provided command as:


```bash

# for fluentd

$ gem install fluent-plugin-quota-throttle
[OR]
$ fluent-gem install fluent-plugin-quota-throttle

```

## Configuration

#### name

The name of the quota. This is used for logging and debugging purposes.

#### description

A description of the quota. This is used for documentation of the defined quota

#### group\_by

Used to group logs into buckets. Quotas are applied to buckets independently.

A dot indicates a key within a sub-object. As an example, in the following log,
the group by key `kubernetes.container_name` resolve to `random`:
```
{"level": "error", "msg": "plugin test", "kubernetes": { "container_name": "random" } }
```

Multiple groups can be specified, in which case each unique pair
of key values are rate limited independently.

If the group cannot be resolved, an anonymous (`nil`) group is used for rate limiting.

#### match\_by

Used to match logs to their respective quotas. If a log does not match any quota, it will be matched to the default quota.

#### bucket\_size

Maximum number logs allowed per groups over the period of `duration`.

This translate to a log rate of `bucket_size/duration`.
When a group exceeds bucket limit, logs from this group are dropped/reemitted with new tag.

For example, the rate is 6000/60s, making for a rate of 100 logs per
seconds.

Note that this is not expressed as a rate directly because there is a
difference between the overall rate and the distribution of logs over a period
time. For example, a burst of logs in the middle of a minute bucket might not
exceed the average rate of the full minute.

Consider `60/60s`, 60 logs over a minute, versus `1/1s`, 1 log per second.
Over a minute, both will emit a maximum of 60 logs. Limiting to a rate of 60
logs per minute. However `60/60s` will readily emit 60 logs within the first
second then nothing for the remaining 59 seconds. While the `1/1s` will only
emit the first log of every second.

#### duration

This is the period of of time over which `bucket_size` applies. This should be given in seconds.

#### action

Either `drop` or `reemit`.

When a group exceeds its rate limit, logs are either dropped or re-emitted with a new tag `secondary.<tag>`



#### warning\_delay

Default: `60` (seconds).

When a group reaches its limit and as long as it is not reset, a warning
message with the current log rate of the group is emitted repeatedly. This is
the delay between every repetition.

## Usage

```xml
<filter **>
  @type quota_throttle
  @path /etc/fluentd/quota_throttle.yaml
  @warning_delay 30s
</filter>
```
```yaml
quotas:
- name: quota1
  description: first quota
  group_by:
  - group1.a
  match_by:
    group1.a: value1
  bucket_size: 100
  duration: 60s
  action: drop
- name: quota2
  description: second quota
  group_by:
  - group1.a
  - group1.b
  match_by:
    group1.a: value2
    group1.b: value3
  bucket_size: 200
  duration: 2m
  action: reemit
- name: quota3
  description: third quota
  group_by:
  - group2
  - group3
  match_by:
      group2: value2
      group3: value3
  bucket_size: 300
  duration: 180s
  action: drop
default:
  description: default quota
  group_by:
    - group1.a
  bucket_size: 300
  duration: 3m
  action: reemit
```

## License

Apache License, Version 2.0

## Copyright

Copyright © 2018 ([Rubrik Inc.](https://www.rubrik.com))
