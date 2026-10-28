package com.ecommerce.excecao;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.sql.SQLException;
import java.util.Map;

/** Converte excecoes em respostas {"message": "..."} com o codigo HTTP certo. */
@RestControllerAdvice
public class GestorErros {

    private static final Logger log = LoggerFactory.getLogger(GestorErros.class);

    @ExceptionHandler(ExcecaoApi.class)
    public ResponseEntity<Map<String, String>> erroApi(ExcecaoApi e) {
        return resposta(e.getEstado(), e.getMessage());
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> corpoInvalido(HttpMessageNotReadableException e) {
        return resposta(HttpStatus.BAD_REQUEST, "Pedido invalido");
    }

    /** Erros do SQL Server (gatilhos, constraints). */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> erroBd(DataAccessException e) {
        SQLException sql = causaSql(e);
        if (sql != null) {
            int codigo = sql.getErrorCode();
            String msg = sql.getMessage() == null ? "" : sql.getMessage();
            switch (codigo) {
                case 50002: return resposta(HttpStatus.BAD_REQUEST, "Cupao invalido ou expirado");
                case 50003: return resposta(HttpStatus.CONFLICT, "Transicao de estado invalida");
                case 50004: return resposta(HttpStatus.CONFLICT, "Uma encomenda sem linhas nao pode ser paga");
                case 50005: return resposta(HttpStatus.CONFLICT, "So e possivel devolver encomendas entregues");
                case 50006: return resposta(HttpStatus.CONFLICT, "Operacao reservada");
                case 547:
                    if (msg.contains("CK_Produto_Stock")) {
                        return resposta(HttpStatus.CONFLICT, "Stock insuficiente");
                    }
                    return resposta(HttpStatus.BAD_REQUEST, "Dados invalidos (violacao de restricao)");
                case 2627:
                case 2601:
                    return resposta(HttpStatus.CONFLICT, "Ja existe um registo com esses dados");
                default:
                    break;
            }
        }
        log.error("Erro de base de dados", e);
        return resposta(HttpStatus.INTERNAL_SERVER_ERROR, "Erro de base de dados");
    }

    /** Parametro mal formado ou em falta (ex.: /api/produtos/abc): 400 e nao 500. */
    @ExceptionHandler({MethodArgumentTypeMismatchException.class, MissingServletRequestParameterException.class})
    public ResponseEntity<Map<String, String>> parametroInvalido(Exception e) {
        return resposta(HttpStatus.BAD_REQUEST, "Pedido invalido");
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> outro(Exception e) {
        // Erros do proprio Spring MVC (404 rota inexistente, 405, 415...) mantem o codigo HTTP original
        if (e instanceof ErrorResponse er) {
            return resposta(HttpStatus.valueOf(er.getStatusCode().value()), "Pedido invalido");
        }
        log.error("Erro interno", e);
        return resposta(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno do servidor");
    }

    /** Procura na cadeia de causas a SQLException (no SQL Server e uma SQLServerException; getErrorCode() e o numero do erro). */
    private static SQLException causaSql(Throwable t) {
        SQLException encontrada = null;
        for (Throwable c = t; c != null; c = c.getCause()) {
            if (c instanceof SQLException && encontrada == null) {
                encontrada = (SQLException) c;
            }
            if (c.getCause() == c) break;
        }
        return encontrada;
    }

    private static ResponseEntity<Map<String, String>> resposta(HttpStatus estado, String msg) {
        return ResponseEntity.status(estado).body(Map.of("message", msg));
    }
}
