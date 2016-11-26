class ViewRenderer

  def initialize(view, json, params, filename)
    @view = view
    @json = json.deep_stringify_keys!
    @params = params
    @filename = filename
  end



  def render
    renderer.render(transformer.transform(view, json), params, filename)
  end

  def transform
    transformer.transform(view, json)
  end

  private
  attr_reader :view, :json, :params, :filename
  def renderer
    Kernel.const_get("ViewRenderer::Render" + view["render"].titleize.gsub(" ",""))
  end

  def transformer
    Kernel.const_get("ViewRenderer::Transform" + view["transform"].titleize.gsub(" ",""))
  end

  class TransformJq
    def self.transform(v, json)
      json.jq(v["template"])[0]
    end
  end

  class TransformJmespath
    def self.transform(v, json)
      JMESPath.search(v["template"], json)
    end
  end

  class RenderChart
    def self.render(json,params,filename)
      ap "format #{params['format']}"
      if params["format"] == "png"
        j = JSON.dump(json)
        i = ::RestClient.post('http://export.highcharts.com/',"content=options&options=#{j}&type=image/png")
        AWS::S3::S3Object.store(filename,i,'dg-tmp')
        return {url: "https://s3.amazonaws.com/dg-tmp/#{filename}"}
      else
        return json
      end
    end
  end

  class RenderJson
    def self.render(json,params,filename)
      return json
    end
  end



  class RenderLiquid
    def self.render(v, json, params, filename)
      html = ::Liquid::Template.parse(v["template"]).render(json.merge("_params" => params)).html_safe
      if params["format"] != "png"
        return html
      elsif params["format"] == "png"
        x = SecureRandom.urlsafe_base64(5)
        File.open("/tmp/#{x}.html","w") {|f| f.write(html) }
        if params["width"]
          `wkhtmltoimage --width #{params["width"]} --disable-smart-width --quality 50 /tmp/#{x}.html /tmp/#{x}.png`
        else
          `wkhtmltoimage /tmp/#{x}.html /tmp/#{x}.png`
        end
        AWS::S3::S3Object.store(filename,open("/tmp/#{x}.png"),'dg-tmp')
        return {url: "https://s3.amazonaws.com/dg-tmp/#{filename}"}
      end
    end
  end

  class Pivot
    def self.render(v, json, params, filename)
      pt = PivotTable.new(json, params)
      pt.render(v["template"].symbolize_keys)
    end
  end

  class ChartJp
    def self.render(v, json, params, filename)
      jp = JMESPath.search(v["template"], json)
      if ["png","uri"].include?(params["format"])
        j = JSON.dump(jp)
        i = ::RestClient.post('http://export.highcharts.com/',"content=options&options=#{j}&type=image/png")
        AWS::S3::S3Object.store(filename,i,'dg-tmp')
        return {url: "https://s3.amazonaws.com/dg-tmp/#{filename}"}
      end
      return jp
    end
  end

end
