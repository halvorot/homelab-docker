#!/bin/bash
set -e;


if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql \
		-v ON_ERROR_STOP=1 \
		-v app_user="$POSTGRES_NON_ROOT_USER" \
		-v app_password="$POSTGRES_NON_ROOT_PASSWORD" \
		-v app_database="$POSTGRES_DB" \
		--username "$POSTGRES_USER" \
		--dbname "$POSTGRES_DB" <<-'EOSQL'
		DO
		$$
		BEGIN
			EXECUTE format('CREATE USER %I WITH PASSWORD %L', :'app_user', :'app_password');
			EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'app_database', :'app_user');
			EXECUTE format('GRANT CREATE ON SCHEMA public TO %I', :'app_user');
		END
		$$;
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi
