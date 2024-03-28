# Tradingview-alert-operator

## Env Variables

```
export DATABASE_URL=postgresql://DBUSER:DBPASSWORD@DBHOST:DBPORT/DBNAME
```

## Run using uvicorn:

```
uvicorn main:app --port 8001 --reload
```