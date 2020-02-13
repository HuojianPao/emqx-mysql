%% Copyright (c) 2013-2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_mysql).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-export([ register_metrics/0
        , check/2
        , description/0
        ]).

-export([ load/1
        , unload/0
        ]).

-export([ on_client_connected/3
        , on_client_disconnected/4
        ]).

-export([ on_message_publish/2
        ]).

-define(EMPTY(Username), (Username =:= undefined orelse Username =:= <<>>)).

load(Env) ->
    emqx:hook('client.connected',    {?MODULE, on_client_connected, [Env]}),
    emqx:hook('client.disconnected', {?MODULE, on_client_disconnected, [Env]}),
    emqx:hook('message.publish',     {?MODULE, on_message_publish, [Env]}).

on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, _Env) ->
    io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
              [ClientId, ClientInfo, ConnInfo]).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, _Env) ->
    io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
              [ClientId, ReasonCode, ClientInfo, ConnInfo]).

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("Publish ~s~n", [emqx_message:format(Message)]),
    {ok, Message}.

unload() ->
    emqx:unhook('client.connected',    {?MODULE, on_client_connected}),
    emqx:unhook('client.disconnected', {?MODULE, on_client_disconnected}),
    emqx:unhook('message.publish',     {?MODULE, on_message_publish}).

register_metrics() ->
    [emqx_metrics:new(MetricName) || MetricName <- ['mysql.success', 'mysql.failure', 'mysql.ignore']].

check(Credentials = #{password := Password}, #{auth_query  := {AuthSql, AuthParams},
                                               super_query := SuperQuery,
                                               hash_type   := HashType}) ->
    CheckPass = case emqx_mysql_cli:query(AuthSql, AuthParams, Credentials) of
                    {ok, [<<"password">>], [[PassHash]]} ->
                        check_pass({PassHash, Password}, HashType);
                    {ok, [<<"password">>, <<"salt">>], [[PassHash, Salt]]} ->
                        check_pass({PassHash, Salt, Password}, HashType);
                    {ok, _Columns, []} ->
                        {error, not_found};
                    {error, Reason} ->
                        ?LOG(error, "[MySQL] query '~p' failed: ~p", [AuthSql, Reason]),
                        {error, not_found}
                end,
    case CheckPass of
        ok ->
            emqx_metrics:inc('mysql.success'),
            {stop, Credentials#{is_superuser => is_superuser(SuperQuery, Credentials),
                                anonymous => false,
                                auth_result => success}};
        {error, not_found} ->
            emqx_metrics:inc('mysql.ignore'), ok;
        {error, ResultCode} ->
            ?LOG(error, "[MySQL] Auth from mysql failed: ~p", [ResultCode]),
            emqx_metrics:inc('mysql.failure'),
            {stop, Credentials#{auth_result => ResultCode, anonymous => false}}
    end.

%%--------------------------------------------------------------------
%% Is Superuser?
%%--------------------------------------------------------------------

-spec(is_superuser(undefined | {string(), list()}, emqx_types:credentials()) -> boolean()).
is_superuser(undefined, _Credentials) -> false;
is_superuser({SuperSql, Params}, Credentials) ->
    case emqx_mysql_cli:query(SuperSql, Params, Credentials) of
        {ok, [_Super], [[1]]} ->
            true;
        {ok, [_Super], [[_False]]} ->
            false;
        {ok, [_Super], []} ->
            false;
        {error, _Error} ->
            false
    end.

check_pass(Password, HashType) ->
    case emqx_passwd:check_pass(Password, HashType) of
        ok -> ok;
        {error, _Reason} -> {error, not_authorized}
    end.

description() -> "Datastore with MySQL".

