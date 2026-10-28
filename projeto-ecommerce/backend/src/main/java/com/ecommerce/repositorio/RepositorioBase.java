package com.ecommerce.repositorio;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;

import java.sql.Types;

/** Utilitarios comuns aos repositorios (acesso JDBC com SQL escrito a mao). */
public abstract class RepositorioBase {

    protected final NamedParameterJdbcTemplate jdbc;

    protected RepositorioBase(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    protected static MapSqlParameterSource params() {
        return new MapSqlParameterSource();
    }

    /** Parametro de texto que pode ser null (tipo explicito para o driver do SQL Server). */
    protected static MapSqlParameterSource texto(MapSqlParameterSource p, String nome, String valor) {
        return p.addValue(nome, valor, Types.VARCHAR);
    }

    /** Parametro inteiro que pode ser null. */
    protected static MapSqlParameterSource inteiro(MapSqlParameterSource p, String nome, Integer valor) {
        return p.addValue(nome, valor, Types.INTEGER);
    }

    /**
     * Executa um INSERT e devolve o identity gerado. Usa chaves geradas do JDBC
     * (e nao OUTPUT INSERTED) porque o SQL Server nao permite OUTPUT sem INTO em tabelas com gatilhos.
     */
    protected int inserirComId(String sql, MapSqlParameterSource p, String colunaId) {
        KeyHolder chave = new GeneratedKeyHolder();
        jdbc.update(sql, p, chave, new String[] {colunaId});
        return chave.getKey().intValue();
    }
}
