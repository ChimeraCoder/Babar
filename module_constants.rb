module Babar
  require 'set'

  Taskfields = Set.new [:id,
                        :title,
                        :tag,
                        :folder,
                        :context,
                        :goal,
                        :location,
                        :parent,
                        :children,
                        :order,
                        :duedate,
                        :duedatemod,
                        :startdate,
                        :duetime,
                        :starttime,
                        :remind,
                        :repeat,
                        :repeatfrom,
                        :status,
                        :length,
                        :priority,
                        :star,
                        :modified,
                        :completed,
                        :added,
                        :timer,
                        :timeron,
                        :note,
                        :meta,
  ]


 
  #Account fields (except those that should be stored as Time objects)
  Accounttextfields = Set.new [:userid,
                               :alias,
                               :pro,
                               :dateformat,
                               :timezone,
                               :hidemonths,
                               :hotlistpriority,
                               :hotlistduedate,
                               :showtabnums,
  ]

  #Account fields that should be stored as Time objects
  Accounttimestamps = Set.new [ 
                               :lastedit_folder,
                               :lastedit_context,
                               :lastedit_goal,
                               :lastedit_task,
                               :lastdelete_task,
                               :lastedit_notebook,
                               :lastdelete_notebooks,

  ]
  
  Accountfields = Accounttimestamps.union Accounttextfields 



end

