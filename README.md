# Tradingview-alert-operator

## Env Variables

```
export DATABASE_URL=postgresql://DBUSER:DBPASSWORD@DBHOST:DBPORT/DBNAME

export DELAY_MINUTES=5
```

## Run using uvicorn:

```
uvicorn main:app --port 8001 --reload
```


### Json for Tradingview Alert in Gold Strategy

{
    "timestamp": "{{timenow}}",
    "signal_type": "{{strategy.order.action}}",
    "prices": "{{strategy.order.alert_message}}",
    "open_position": "{{strategy.order.id}}"
}
