set head off
set feedback off
set lines 300
set pages 3000
set serveroutput on;
declare
v_inscnt number;
v_dfcnt number;
v_dfstat number;
v_dfval varchar2(3);
v_regcnt number;
v_regstat number;
v_regval varchar2(3);
v_objcnt number;
v_objstat number;
v_objval varchar2(3);
v_dobjval varchar2(3);
v_indcnt number;
v_indval varchar2(3);
v_pacnt number;
v_paval varchar2(3);
v_alertcnt number;
v_alertval varchar2(3);
v_dbhlthsum number;
v_dbname varchar2(8);
v_dbstatus varchar2(20);
v_dbid number;
begin
/* section to check db availability */
select name,open_mode into v_dbname,v_dbstatus from v$database;
if (v_dbstatus = 'READ WRITE' OR v_dbstatus = 'READ ONLY') then
        /* take down dbid of the database to compute health sum */
                select dbid into v_dbid from v$database;
                select count(1) into v_inscnt from gv$instance;
        /* section below is to check datafile health */
        select count(1) into v_dfcnt from v$datafile;
        select count(1) into v_dfstat from v$datafile where status in ('ONLINE','SYSTEM');
                if (v_dfcnt = v_dfstat) then
                        v_dfval:='YES';
                else
                        v_dfval:='NOT';
                end if;
        /* section below is to check registry health */
        select count(1) into v_regcnt from dba_registry;
        select count(1) into v_regstat from dba_registry where status in ('OPTION OFF','VALID'); /* OPTION OFF to account for any RAC component being in disabled state */
                if (v_regcnt = v_regstat) then
                        v_regval:='YES';
                else
                        v_regval:='NOT';
                end if;
        /* section below is to count INVALID object */
        select count(1) into v_objcnt from dba_objects where status='INVALID' and ( owner in (select schema from dba_registry) OR owner in ('AUDSYS','APPQOSSYS','ANONYMOUS','APEX_PUBLIC_USER','BI','CTXSYS','DBSNMP','DIP','DVF','EXFSYS','FLOWS_30000','FLOWS_FILES','GSMCATUSER','GSMUSER','HR','IX','LBACSYS','MDDATA','MDSYS','MGMT_VIEW','OE','OJVMSYS','OLAPSYS','ORACLE_OCM','ORDPLUGINS','ORDSYS','OUTLN','OWBSYS','PM','SH','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','SYSMAN','SYSTEM','SYSDG','SYSKM','SYSBACKUP','WK_TEST','WKPROXY','WKSYS','WMSYS','XDB','XS$NULL','FLOWS_040100','ORDDATA','TSMSYS','GSMADMIN_INTERNAL') OR owner like 'APEX%');
                if (v_objcnt = 0) then
                        v_objval:='YES';
                else
                        v_objval:='NOT';
                end if;
        select count(1) into v_objstat from dba_objects where status='INVALID' and owner in ('SYS','SYSTEM');
                if (v_objstat = 0) then
                        v_dobjval:='YES';
                else
                        v_dobjval:='NOT';
                end if;
        /* section below is to check INVALID index in sys */
        select count(1) into v_indcnt from dba_indexes where status='UNUSABLE' and owner in ('SYS','SYSTEM');
                if (v_indcnt = 0) then
                        v_indval:='YES';
                else
                        v_indval:='NOT';
                end if;
        /* section below is to check patching status in registry */
        select count(1) into v_pacnt from dba_registry_sqlpatch where status!='SUCCESS';
                if (v_pacnt = 0) then
                        v_paval:='YES';
                else
                        v_paval:='NOT';
                end if;
        /* section below is to check alert log for ORA- errors in all the rac cluster nodes */
        select count(1) into v_alertcnt from TABLE(GV$(CURSOR(select inst_id,ORIGINATING_TIMESTAMP TSTMP,MESSAGE_TEXT msgtxt from X$DBGALERTEXT where MESSAGE_TEXT like 'ORA-%' and MESSAGE_TEXT not like 'ORA-1109%' and ORIGINATING_TIMESTAMP> sysdate -5/24)));
                if (v_alertcnt = 0) then
                        v_alertval:='YES';
                else
                        v_alertval:='NOT';
                end if;
        v_dbhlthsum:=v_dbid+v_inscnt+v_dfcnt+v_regcnt+v_objcnt+v_indcnt+v_pacnt+v_alertcnt;
        if (v_dfval = 'YES' AND v_regval = 'YES' AND v_objval = 'YES' AND  v_dobjval = 'YES' AND v_indval = 'YES' AND v_paval = 'YES' AND v_alertval = 'YES') then
        dbms_output.put_line('GOOD PROCEED WITH THE SANITY - DB NAME: '||v_dbname||' - '||'HEALTH SUM: '||v_dbhlthsum);
        else
        dbms_output.put_line('DONT PROCEED WITH THE SANITY - DB NAME: '||v_dbname||' - '||' HEALTH SUM: '||v_dbhlthsum);
        dbms_output.put_line('DBFILE_HLTHY - REGIST_HLTHY - NODINV_PRSNT - NOINVO_PRSNT - NOINIX_PRSNT - NOPATC_FAILU - NOALRT_PRSNT');
        dbms_output.put_line(rpad(v_dfval,13)||'- '||rpad(v_regval,13)||'- '||rpad(v_dobjval,13)||'- '||rpad(v_objval,13)||'- '||rpad(v_indval,13)||'- '||rpad(v_paval,13)||'- '||rpad(v_alertval,13));
        end if;
else
dbms_output.put_line(v_dbname||' isnt in either of READ WRITE or READ ONLY mode to compute db healthsum');
end if;
exception
when others then
raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
end;
/
exit;