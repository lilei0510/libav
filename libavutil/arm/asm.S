/*
 * Copyright (c) 2008 Mans Rullgard <mans@mansr.com>
 *
 * This file is part of Libav.
 *
 * Libav is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * Libav is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Libav; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "config.h"
\
#ifdef __ELF__
#   define ELF
#else
#   define ELF @
#endif

#if CONFIG_THUMB
#   define A @
#   define T
#else
#   define A
#   define T @
#endif

#if CONFIG_EZX
#   define ldm ldmia
#   define pop ldmfd sp!,
#   define pople pop
#   define push stmfd sp!,
#   define stm stmia
#   define ELF_X @
#   define IT(op)
#   define ITT(op)
#   define ITTT(op)
#   define ITTTT(op)
#else
#   define ELF_X
#   define IT(op) it op
#   define ITT(op) itt op
#   define ITTT(op) ittt op
#   define ITTTT(op) itttt op
#endif //CONFIG_EZX

#define USE_NEW_CODE 1
#if   HAVE_NEON
        .arch           armv7-a
#elif HAVE_ARMV6T2
        .arch           armv6t2
#elif HAVE_ARMV6
        .arch           armv6
#elif HAVE_ARMV5TE && (!(CONFIG_EZX) || USE_NEW_CODE)
        .arch           armv5te
#endif

#if   HAVE_NEON
        .fpu            neon
#elif HAVE_ARMVFP
        .fpu            vfp
#endif

#if !(CONFIG_EZX)
        .syntax unified
#endif
T       .thumb

.macro  require8 val=1
ELF     .eabi_attribute 24, \val
.endm

.macro  preserve8 val=1
ELF     .eabi_attribute 25, \val
.endm

.macro  function name, export=0
#if !(CONFIG_EZX) || USE_NEW_CODE
    .set            .Lpic_idx, 0
    .set            .Lpic_gp, 0
#endif
    .macro endfunc
#if !(CONFIG_EZX) || USE_NEW_CODE
      .if .Lpic_idx
        .altmacro
        put_pic         %(.Lpic_idx - 1)
        .noaltmacro
      .endif
#endif
ELF     .size   \name, . - \name
        .endfunc
        .purgem endfunc
    .endm
        .text
        .align          2
    .if \export
        .global EXTERN_ASM\name
EXTERN_ASM\name:
    .endif
ELF     .type   \name, %function
        .func   \name
\name:
.endm

.macro  const   name, align=2
    .macro endconst
ELF     .size   \name, . - \name
        .purgem endconst
    .endm
        .section        .rodata
        .align          \align
\name:
.endm

#if !HAVE_ARMV6T2 && (!(CONFIG_EZX) || USE_NEW_CODE)
.macro  movw    rd, val
        mov     \rd, \val &  255
        orr     \rd, \val & ~255
.endm
#endif

.macro  mov32   rd, val
#if HAVE_ARMV6T2
        movw            \rd, #(\val) & 0xffff
    .if (\val) >> 16
        movt            \rd, #(\val) >> 16
    .endif
#else
        ldr             \rd, =\val
#endif
.endm

.macro  put_pic         num
        put_pic_\num
.endm

#if !(CONFIG_EZX) || USE_NEW_CODE
.macro  do_def_pic      num, val, label
    .macro put_pic_\num
      .if \num
        .altmacro
        put_pic         %(\num - 1)
        .noaltmacro
      .endif
\label: .word           \val
        .purgem         put_pic_\num
    .endm
.endm

.macro  def_pic         val, label
        .altmacro
        do_def_pic      %.Lpic_idx, \val, \label
        .noaltmacro
        .set            .Lpic_idx, .Lpic_idx + 1
.endm

.macro  ldpic           rd,  val, indir=0
        ldr             \rd, .Lpicoff\@
.Lpic\@:
    .if \indir
        ldr             \rd, [pc, \rd]
    .else
        add             \rd, pc,  \rd
    .endif
        def_pic         \val - (.Lpic\@ + (8 >> CONFIG_THUMB)), .Lpicoff\@
.endm
#endif

.macro  movrel rd, val
#if CONFIG_PIC && !(CONFIG_EZX) /* */
        ldpic           \rd, \val
#elif HAVE_ARMV6T2 && !defined(__APPLE__)
        movw            \rd, #:lower16:\val
        movt            \rd, #:upper16:\val
#else
        ldr             \rd, =\val
#endif
.endm

#if !(CONFIG_EZX) || USE_NEW_CODE
.macro  movrelx         rd,  val, gp
#if CONFIG_PIC && defined(__ELF__)
    .ifnb \gp
      .if .Lpic_gp
        .unreq          gp
      .endif
        gp      .req    \gp
        ldpic           gp,  _GLOBAL_OFFSET_TABLE_
    .elseif !.Lpic_gp
        gp      .req    r12
        ldpic           gp,  _GLOBAL_OFFSET_TABLE_
    .endif
        .set            .Lpic_gp, 1
        ldr             \rd, .Lpicoff\@
        ldr             \rd, [gp, \rd]
        def_pic         \val(GOT), .Lpicoff\@
#elif CONFIG_PIC && defined(__APPLE__)
        ldpic           \rd, .Lpic\@, indir=1
        .non_lazy_symbol_pointer
.Lpic\@:
        .indirect_symbol \val
        .word           0
        .text
#else
        movrel          \rd, \val
#endif
.endm
#endif

.macro  ldr_pre         rt,  rn,  rm:vararg
A       ldr             \rt, [\rn, \rm]!
T       add             \rn, \rn, \rm
T       ldr             \rt, [\rn]
.endm

.macro  ldr_dpre        rt,  rn,  rm:vararg
A       ldr             \rt, [\rn, -\rm]!
T       sub             \rn, \rn, \rm
T       ldr             \rt, [\rn]
.endm

#if !(CONFIG_EZX) || USE_NEW_CODE
.macro  ldr_nreg        rt,  rn,  rm:vararg
A       ldr             \rt, [\rn, -\rm]
T       sub             \rt, \rn, \rm
T       ldr             \rt, [\rt]
.endm
#endif

.macro  ldr_post        rt,  rn,  rm:vararg
A       ldr             \rt, [\rn], \rm
T       ldr             \rt, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  ldrd_reg        rt,  rt2, rn,  rm
A       ldrd            \rt, \rt2, [\rn, \rm]
T       add             \rt, \rn, \rm
T       ldrd            \rt, \rt2, [\rt]
.endm

.macro  ldrd_post       rt,  rt2, rn,  rm
A       ldrd            \rt, \rt2, [\rn], \rm
T       ldrd            \rt, \rt2, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  ldrh_pre        rt,  rn,  rm
A       ldrh            \rt, [\rn, \rm]!
T       add             \rn, \rn, \rm
T       ldrh            \rt, [\rn]
.endm

.macro  ldrh_dpre       rt,  rn,  rm
A       ldrh            \rt, [\rn, -\rm]!
T       sub             \rn, \rn, \rm
T       ldrh            \rt, [\rn]
.endm

.macro  ldrh_post       rt,  rn,  rm
A       ldrh            \rt, [\rn], \rm
T       ldrh            \rt, [\rn]
#if !(CONFIG_EZX) || USE_NEW_CODE
T       add             \rn, \rn, \rm
.endm

.macro  ldrb_post       rt,  rn,  rm
A       ldrb            \rt, [\rn], \rm
T       ldrb            \rt, [\rn]
#endif
T       add             \rn, \rn, \rm
.endm

.macro  str_post       rt,  rn,  rm:vararg
A       str             \rt, [\rn], \rm
T       str             \rt, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  strb_post       rt,  rn,  rm:vararg
A       strb            \rt, [\rn], \rm
T       strb            \rt, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  strd_post       rt,  rt2, rn,  rm
A       strd            \rt, \rt2, [\rn], \rm
T       strd            \rt, \rt2, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  strh_pre        rt,  rn,  rm
A       strh            \rt, [\rn, \rm]!
T       add             \rn, \rn, \rm
T       strh            \rt, [\rn]
.endm

.macro  strh_dpre       rt,  rn,  rm
A       strh            \rt, [\rn, -\rm]!
T       sub             \rn, \rn, \rm
T       strh            \rt, [\rn]
.endm

.macro  strh_post       rt,  rn,  rm
A       strh            \rt, [\rn], \rm
T       strh            \rt, [\rn]
T       add             \rn, \rn, \rm
.endm

.macro  strh_dpost       rt,  rn,  rm
A       strh            \rt, [\rn], -\rm
T       strh            \rt, [\rn]
T       sub             \rn, \rn, \rm
.endm

#if HAVE_VFP_ARGS
        .eabi_attribute 28, 1
#   define VFP
#   define NOVFP @
#else
#   define VFP   @
#   define NOVFP
#endif

#define GLUE(a, b) a ## b
#define JOIN(a, b) GLUE(a, b)
#define X(s) JOIN(EXTERN_ASM, s)
