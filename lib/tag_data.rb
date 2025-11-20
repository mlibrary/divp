#!/usr/bin/env ruby
# frozen_string_literal: true

module TagData
  # Map of artist code to 315
  ARTIST = {"bentley" => "University of Michigan: Bentley Historical Library",
            "clements" => "University of Michigan: William L Clements Library",
            "dcu" => "University of Michigan: Digital Conversion Unit",
            "mpub" => "University of Michigan: Michigan Publishing"}.freeze
  # Map of scanner code to 271 and 272 make and model
  SCANNER = {"atiz" => ["Atiz", "BookDrive Pro"],
             "copibook294703" => %w[CopiBook HD],
             "copibook355002" => %w[CopiBook Cobalt],
             "copibookcobalt" => ["i2S DigiBook", "CopiBook Cobalt"],
             "copibookos" => ["i2S DigiBook", "CopiBook Open System"],
             "copibookv" => ["i2S DigiBook", "CopiBook V"],
             "epson" => %w[Epson GT20000],
             "flatbed" => ["Epson", "Expression 10000XL"],
             "fujitsu" => ["Fujitsu", "CopiBook V"],
             "phaseone45" => ["Phase One", "P45+"],
             "phaseoneiq3" => ["Phase One", "IQ3"],
             "photo" => ["Phase One", "P45+"], # duplicate of phaseone
             "quartz" => ["i2S DigiBook", "SupraScan Quartz A1V"],
             "quartza0" => ["i2S DigiBook", "Suprascan Quartz A0"],
             "treventus" => ["Treventus", "ScanRobot 2.0 MDS"],
             "z5k" => %w[Zeutschel Z5000],
             "z7k" => %w[Zeutschel Z7000],
             "z10k" => %w[Zeutschel Z10000]}.freeze
  # Map of software to 305
  SOFTWARE = {"acdsee" => "ACDSee 10.0 Photo Manager (Build 238)",
              "acdsee8" => "ACDSee Pro 8",
              "book_restorer" => "Book Restorer (TM) 3.0.0.44",
              "digibook6" => "Digibook 6",
              "iirisa" => "IIRISA 1.08.85.0",
              "limb112" => "Limb (TM) 1.1.2",
              "limb200" => "Limb (TM) 2.0.0",
              "limb4000" => "Limb (TM) 4.0.0.0",
              "limb" => "LIMB 4.3.0.0",
              "photoshop5" => "Adobe Photoshop CS5",
              "photoshop6" => "Adobe Photoshop CS6",
              "photoshop2015" => "Adobe Photoshop CC 2015",
              "clements" => "Digital Photo Professional",
              "silverfast" =>
               "SilverFast 8.2.0 r1 (Oct  1 2014)  ba0a28b 01.10.",
              "yooscan" => "YooScan 1.7.5.1"}.freeze
end
