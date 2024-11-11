#archivelog mode and space availability verify module
        chk=$(sqlplus -s "/as sysdba" <<' EOF'
        set head off
        set feedback off
        set echo off
        set trim on
        set trims on
        set pagesize 0
        col distnum for 9999
        select (case a.log_mode
                when 'ARCHIVELOG' then a.log_mode||','||b.dest
                else a.log_mode
                end) archdest
        from v$database a
        ,(select (case upper(b.logdest)
            when 'LOCATION=USE_DB_RECOVERY_FILE_DEST' then e.dbrecodest
            when 'NO_DBRECO_DEST' then e.dbrecodest
            else upper(b.logdest)||','||'0' end) dest
        from
        (select nvl(max(case nvl(pf.value,'NOVAL')	--- this subquery evaluates log_archive_dest value
            when 'NOVAL' then 'NO_DBRECO_DEST'
            else upper(value)
            end),'DONT_PROCEED') logdest
        from (select (case when  count(distinct(value)) <= 1 then 'OK' else 'NOK' end) pchk from gv$parameter where lower(name)='log_archive_dest_1') sp, v$parameter pf --- this subquery returns OK when log_archive_dest is either set to a unique value or no value.
        where lower(pf.name)='log_archive_dest_1'
        and sp.pchk='OK') b,
        (select (case upper(nvl(c.value,'NOVAL'))		--- this subquery evaluates db_recovery_file_dest setup
            when 'NOVAL' then 'NOVAL,0'
            else upper(c.value)||','||upper(d.value)
            end) dbrecodest
        from v$parameter c,v$parameter d
        where lower(c.name)='db_recovery_file_dest'
        and lower(d.name)='db_recovery_file_dest_size'
        ) e) b;
        exit;
        EOF
        );
        archmd=$(echo $chk|cut -d ',' -f 1);
        if [[ "$archmd" == "ARCHIVELOG" ]]
        then
            archdest=$(echo $chk|cut -d ',' -f 2);
            if [[ "$archdest" != "NOVAL" ]]
            then
                if [[ "$archdest" != "LOCA*" ]]
                then
                    export ORACLE_SID={{ dbname }};export ORAENV_ASK=NO;. oraenv > /dev/null;
                    archdestsz=$(sqlplus -s "/as sysdba" <<' EOF'
                    set head off
                    set feedback off
                    set echo off
                    set trim on
                    set trims on
                    set pagesize 0
                    col distnum for 9999
                    set numformat 99999999999999999
                    select (space_limit-space_used+space_reclaimable) from v$recovery_file_dest;
                    exit;
                    EOF
                    );
                elsif [[ "$archdest" = "LOCATION=/*" ]]
                then
                    archfs=$(echo $chk|cut -d ',' -f 2|cut -d "=" -f 2);
                    archdeststg=$(df -h $archfs|grep -v "Filesystem"|awk '{print $4}');
                    archdestsz=$(( 1024*$archdeststg ));
                else [[ "$archdest" = "LOCATION=+*" ]]
                    archfs=$(echo $chk|cut -d ',' -f 2|cut -d "+" -f 2);
                    export ORAENV_ASK=NO;export ORACLE_SID=$(cat /etc/oratab|grep -Ev "^#|^$"|grep ASM|cut -d ":" -f 1'); . oraenv;
                    archdeststg=$(asmcmd lsdg $archfs|grep -v Free_MB|awk '{print $8}');
                    archdestsz=$(( 1048576*$archdeststg ));
                fi
            else
                archdestsz=0;
            fi
        else
            archdestsz=0;
        fi
