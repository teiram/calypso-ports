// Super Cassette Vision - common definitions
//
// Copyright (c) 2024 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

package scv_pkg;

// Human-Machine Interface inputs
typedef struct packed {
  // CONTROLLER buttons (joysticks)
  struct packed {
    bit l, r, u, d;             // directions
    bit t1, t2;                 // L/R orange triggers
  } c1, c2;
  // Console hard buttons (SELECT, PAUSE)
  bit [9:0] num;
  bit cl;
  bit en;
  bit pause;
} hmi_t;

// Cartridge memory mappers
typedef enum bit [3:0]
{
 MAPPER_AUTO = 4'd0,            // reserved for automatic detection
 MAPPER_ROM8K,
 MAPPER_ROM16K,
 MAPPER_ROM32K,
 MAPPER_ROM32K_RAM8K,
 MAPPER_ROM64K,
 MAPPER_ROM128K,
 MAPPER_ROM128K_RAM4K
} mapper_t;

// VDC palette selection
typedef enum bit [0:0]
{
 PALETTE_RGB = 1'd0,
 PALETTE_RF
} palette_t;

// VDC overscan mask size
typedef enum bit [1:0]
{
 OVERSCAN_MASK_LARGE = 2'd0,
 OVERSCAN_MASK_SMALL,
 OVERSCAN_MASK_NONE
} overscan_mask_t;

endpackage
