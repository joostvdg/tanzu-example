# RabbitMQ Training

* https://tanzu.academy/courses/rabbitmq-icm

## Install on MacOs

* https://www.rabbitmq.com/docs/install-homebrew

### Brew Install

```sh
brew update
brew install rabbitmq
```

```sh
brew info rabbitmq
```

### Run RabbitMQ

```sh
CONF_ENV_FILE="/opt/homebrew/etc/rabbitmq/rabbitmq-env.conf" /opt/homebrew/opt/rabbitmq/sbin/rabbitmq-server
```

You can then connect to RabbitMQ or login to the management console: http://localhost:15672/#/
Default user is `guest` and `guest`.

In another terminal, you can enable all features:

```sh
# highly recommended: enable all feature flags on the running node
/opt/homebrew/sbin/rabbitmqctl enable_feature_flag all
```

## Create Queue

* through the Management consoel we can create a Queue called `stock.us`.
* bind the queue to an exchange -> amq.fanout
    * select exchange `amq.fanout`
    * select `binding`
    * `create new binding`
    * to queue `stock.us`
    * hit `bind`
* Publish message
    * Routing key: `rabbitmq`
    * Payload: _any string message_
* View message via Queue's tab
    * select our queue
    * get messages
