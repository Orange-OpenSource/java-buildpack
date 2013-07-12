# Jonas Container
The Jonas Container allows web application to be run within the [OW2 Jonas JEE Container]:http://jonas.ow2.org/ .

 <table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>WEB-INF/</tt> folder in the application directory for WARs or for EARs an <tt>META-INF/application.xml file</tt>  </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>tomcat-&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

Jonas traces appear in app/.jonas_base/logs including JUL traces.


## Limitations

- WAR applications are accessible through the "app" contextRoot.
- DataSources are not yet generated for services bound in CF
- Failed application start is not reliably detected: Tomcat support jar is not yet added in the tomcat lifecyle
- The list of activated jonas can not yet be configured through th
- Jonas embeds some classes in its classpath that may conflict with application embedded jars: spring, cxf, javax.validation, see suggested classloader filtering below as a workaround

## Technical debt and next refactorings

- too many operations are performed in the start command, altough jonas jasmine deployme command is'nt helping much with buildpack requirements (dynamic port resolution + dynamic datasource generation)
- the start cmd generation in jonas.rb could benefit from ERB templating.
- lack unit tests on topology.xml

## Planned improvements

- DataSource generation
- expose CF envs as JNDI entries

## Configuration
The container can be configured by modifying the [`config/jonas.yml`][jonas_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[jonas_yml]: ../config/jonas.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Jonas repository index ([details][util_repositories]).
| `version` | The version of Jonas to use. Candidate versions can be found in [this listing][jonas_index_yml].

[jonas_index_yml]: http://orange-buildpacks-binaries.s3-website-us-west-1.amazonaws.com/jonas/index.yml


## Credits

This container is largely inspired from the tomcat container. Thanks to the cloudfoundry team for the great extensible
java-buildback

## Suggested classloader_filtering

```
<?xml version="1.0" encoding="UTF-8"?>
<class-loader-filtering xmlns="http://org.ow2.jonas.lib.loader.mapping">

	<!-- List of filters used to exclude packages/resources that are used internally
		by the application. -->
	<default-filters>

		<filter-name>org.apache.commons.digester.*</filter-name>

		<filter-name>javax.persistence.*</filter-name>

		<!-- solve this exception : javax.validation.ValidationException: Could
			not create Configuration. at javax.validation.Validation$GenericBootstrapImpl.configure(Validation.java:198)
			~[ow2-validation-1.0-spec-1.0.6.jar:na] at javax.validation.Validation.buildDefaultValidatorFactory(Validation.java:67)
			 -->
		<filter-name>javax.validation.*</filter-name>

		<!-- solve this exception : org.springframework.beans.factory.BeanCreationException:
			Error creating bean with name 'org.apache.cxf.binding.soap.customEditorConfigurer'
			defined in class path resource [META-INF/cxf/cxf-extension-soap.xml]: Initialization
			of bean failed; nested exception is org.springframework.beans.ConversionNotSupportedException:
			Failed to convert property value of type 'java.util.ArrayList' to required
			type 'org.springframework.beans.PropertyEditorRegistrar[]' for property 'propertyEditorRegistrars';
			nested exception is java.lang.IllegalStateException: Cannot convert value
			of type [org.apache.cxf.binding.soap.spring.SoapVersionRegistrar] to required
			type [org.springframework.beans.PropertyEditorRegistrar] for property 'propertyEditorRegistrars[0]':
			no matching editors or conversion strategy found at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.doCreateBean(AbstractAutowireCapableBeanFactory.java:527)
			~[spring-beans-3.0.6.RELEASE.jar:3.0.6.RELEASE] -->
		<filter-name>org.apache.cxf.*</filter-name>
		<!-- solve this exception : Caused by: java.lang.NoSuchMethodException:
			NoSuchMethodException : org.apache.ws.commons.schema.XmlSchemaCollection.read(org.w3c.dom.Document,
			java.lang.String) : org.apache.ws.commons.schema.XmlSchema at org.apache.cxf.common.xmlschema.SchemaCollection.read(SchemaCollection.java:130) -->
		<filter-name>org.apache.ws.*</filter-name>
		<!-- needed to not use cxf.xml within Jonas files -->
		<filter-name>META-INF/cxf/.*</filter-name>


		<filter-name>antlr.*</filter-name>

		<!-- -solve this exception : Caused by: java.lang.LinkageError: loader
			constraint violation in interface itable initialization: when resolving method
			"net.sf.cglib.core.ClassEmitter.setTarget(Lnet/sf/cglib/asm/ClassVisitor;)V"
			the class loader (instance of org/apache/felix/framework/ModuleImpl$ModuleClassLoaderJava5)
			of the current class, net/sf/cglib/transform/ClassEmitterTransformer, and
			the class loader (instance of org/ow2/jonas/web/tomcat6/loader/NoSystemAccessWebappClassLoader)
			for interface net/sf/cglib/transform/ClassTransformer have different Class
			objects for the type net/sf/cglib/asm/ClassVisitor used in the signature -->
		<filter-name>net.sf.cglib.*</filter-name>

		<!-- solve this exception : Caused by: org.hibernate.AnnotationException:
			java.lang.NoSuchMethodException: org.hibernate.validator.ClassValidator.<init>(java.lang.Class,
			java.util.ResourceBundle, org.hibernate.validator.MessageInterpolator, java.util.Map,
			org.hibernate.annotations.common.reflection.ReflectionManager) at org.hibernate.cfg.AnnotationConfiguration.applyHibernateValidatorLegacyConstraintsOnDDL(AnnotationConfiguration.java:455) -->
		<filter-name>org.hibernate.*</filter-name>

		<!-- Use provided Spring -->
		<filter-name>org.springframework.*</filter-name>

		<!-- filter for slf4j to force local slf4j->logback configuration (otherwise,
			the slf4j->monolog configuration from jonas is used) -->
		<filter-name>org.slf4j.*</filter-name>

		<!-- filter for commons logging (JCL) to avoid StackOverflowError caused
			by recursive calls between JCL bridge in war and JCL implementation in Jonas -->
		<filter-name>org.apache.commons.logging.*</filter-name>

		<!-- Should be deleted after log4j to slf4j+logback migration -->
		<filter-name>org.apache.log4j.*</filter-name>

		<!-- Solve following exception when deploying ear on a jonas instance configured with:
			Error creating bean with name 'myEntityManagerFactory'
			Invocation of init method failed; nested exception is java.lang.NoSuchMethodError: org.jboss.logging.Logger.getMessageLogger(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/Object;
		 -->
		<filter-name>org.jboss.logging.*</filter-name>

	</default-filters>
</class-loader-filtering>
```
