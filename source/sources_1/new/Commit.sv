`timescale 1ns / 1ps
`include "defines/defines.svh"

module Commit(
    input wire                  clk,
    input wire                  rst,

    Ctrl.slave                  ctrl_commit,
    ROB_Commit.commit           rob_commit,
    BackendRedirect.backend     backend_if0,
    BPDUpdate.backend           backend_bpd,
    NLPUpdate.backend           backend_nlp,

    output logic                commit_rename_valid_0,
    output logic                commit_rename_valid_1,
    input  commit_info          commit_rename_req_0,
    input  commit_info          commit_rename_req_1
);

    logic           takePredFailed;
    logic           addrPredFailed;
    logic           predFailed;
    logic           waitDS;
    logic           lastWaitDs;
    logic [31:0]    target;
    logic [31:0]    lastTarget;
    logic           causeExec;
    ExceptionType   exception;
    logic [19:0]    excCode;

    assign takePredFailed   = rob_commit.uOP0.branchType != typeNormal && rob_commit.uOP0.branchTaken != rob_commit.uOP0.predTaken;
    assign addrPredFailed   = !takePredFailed && (rob_commit.uOP0.branchAddr != rob_commit.uOP0.predAddr);
    assign target           = rob_commit.uOP0.branchTaken ? rob_commit.uOP0.branchAddr : rob_commit.uOP0.pc + 32'h8;

    always_ff @(posedge clk) begin
        if(takePredFailed || addrPredFailed) begin
            predFailed                      <= `TRUE;
            waitDS                          <= rob_commit.uOP1.uOP == MDBUBBLE_U;
        end else begin
            predFailed                      <= `FALSE;
            waitDS                          <= `FALSE;
        end

        lastWaitDs                          <= waitDS;
        lastTarget                          <= target;
        causeExec                           <= rob_commit.uOP0.causeExc || rob_commit.uOP1.causeExc;
        exception                           <= rob_commit.uOP1.causeExc ? rob_commit.uOP1.exception : rob_commit.uOP0.exception;
        excCode                             <= rob_commit.uOP1.causeExc ? rob_commit.uOP1.excCode : rob_commit.uOP0.excCode;
        
        commit_rename_valid_0               <= rob_commit.uOP0.valid;
        commit_rename_valid_1               <= rob_commit.uOP1.valid;

        commit_rename_req_0.committed_arf   <= rob_commit.uOP0.dstLAddr;
        commit_rename_req_0.committed_prf   <= rob_commit.uOP0.dstPAddr;
        commit_rename_req_0.stale_prf       <= rob_commit.uOP0.dstPStale;

        commit_rename_req_1.committed_arf   <= rob_commit.uOP1.dstLAddr;
        commit_rename_req_1.committed_prf   <= rob_commit.uOP1.dstPAddr;
        commit_rename_req_1.stale_prf       <= rob_commit.uOP1.dstPStale;

        commit_rename_req_0.wr_reg_commit   <= rob_commit.uOP0.dstwe;
        commit_rename_req_1.wr_reg_commit   <= rob_commit.uOP1.dstwe;
    end

    always_comb begin
        if((predFailed && !waitDS) || lastWaitDs) begin
            ctrl_commit.flushReq    = `TRUE;
            backend_if0.redirect    = `TRUE;
            backend_if0.valid       = `TRUE;
            backend_if0.redirectPC  = target;
        end else begin
            ctrl_commit.flushReq    = `FALSE;
            backend_if0.redirect    = `FALSE;
            backend_if0.valid       = `FALSE;
            backend_if0.redirectPC  = 32'h0;
        end
    end

endmodule
