#!/usr/bin/env zx
$.verbose = false;
const clipboard = await $`cliphist list`;
const line = clipboard.stdout.split("\n")[0];
const firstLetters = line
  .split(" ")
  .map((s, i) => (i === 0 ? "" : s))
  .join(" ")
  .trim()
  .substring(0, 5)
  .trim();
console.log(`${firstLetters}...`);
